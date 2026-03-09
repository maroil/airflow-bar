import SwiftUI
import AirflowBarCore

// MARK: - Models

struct EditableEnvironment: Identifiable {
    let id: UUID
    var name: String
    var baseURL: String
    var authType: AuthType
    var username: String
    var password: String
    var token: String
    var isEnabled: Bool

    enum AuthType: String, CaseIterable {
        case basicAuth = "Basic Auth"
        case bearerToken = "Bearer Token"
    }

    var credential: AuthCredential {
        switch authType {
        case .basicAuth: .basicAuth(username: username, password: password)
        case .bearerToken: .bearerToken(token)
        }
    }

    init(from env: AirflowEnvironment) {
        self.id = env.id
        self.name = env.name
        self.baseURL = env.baseURL
        self.isEnabled = env.isEnabled
        switch env.credential {
        case .basicAuth(let u, let p):
            self.authType = .basicAuth; self.username = u; self.password = p; self.token = ""
        case .bearerToken(let t):
            self.authType = .bearerToken; self.username = ""; self.password = ""; self.token = t
        }
    }

    init() {
        self.id = UUID(); self.name = "New Environment"; self.baseURL = ""
        self.authType = .basicAuth; self.username = ""; self.password = ""; self.token = ""
        self.isEnabled = true
    }
}

enum ConnectionTestState: Equatable {
    case idle, testing, success(String), failure(String)
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, display, alerts, environments

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "General"
        case .display: "Display"
        case .alerts: "Alerts"
        case .environments: "Environments"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .display: "eye"
        case .alerts: "bell.badge"
        case .environments: "server.rack"
        }
    }
}

// MARK: - Main View

struct SettingsView: View {
    let configStore: ConfigStore
    let updateViewModel: UpdateCheckViewModel
    let onSave: () -> Void

    @State private var selectedSection: SettingsSection = .general
    @State private var editableEnvironments: [EditableEnvironment] = []
    @State private var selectedEnvId: UUID?
    @State private var refreshInterval: RefreshInterval = .fiveMinutes
    @State private var showPausedDAGs: Bool = false
    @State private var dagFilter: String = ""
    @State private var notifyOnFailure: Bool = true
    @State private var notifyOnRecovery: Bool = true
    @State private var checkForUpdates: Bool = true
    @State private var saveError: String?
    @State private var urlValidationError: String?
    @State private var regexValidationError: String?
    @State private var connectionTestState: ConnectionTestState = .idle

    private var selectedEnvIndex: Int? {
        editableEnvironments.firstIndex(where: { $0.id == selectedEnvId })
    }

    private var selectedEnv: EditableEnvironment? {
        guard let idx = selectedEnvIndex else { return nil }
        return editableEnvironments[idx]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider()
                content
            }
            Divider()
            footer
        }
        .frame(width: 620, height: 480)
        .onAppear(perform: loadCurrentConfig)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedSection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.label, systemImage: section.icon)
                        .font(.system(size: 12))
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 160)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selectedSection {
                case .general: generalPage
                case .display: displayPage
                case .alerts: alertsPage
                case .environments: environmentsPage
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - General Page

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader("General", subtitle: "Global preferences for AirflowBar")

            settingsCard {
                formField("Refresh interval") {
                    Picker("", selection: $refreshInterval) {
                        ForEach(RefreshInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 140)
                }
                Text("How often to poll all environments for updates.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            settingsCard {
                HStack {
                    Toggle(isOn: $checkForUpdates) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Check for updates automatically")
                                .font(.system(size: 12))
                            Text("Checks GitHub once per day for new releases")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    if updateViewModel.isChecking {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    } else if updateViewModel.hasUpdate, let update = updateViewModel.availableUpdate {
                        Button {
                            updateViewModel.openReleasePage()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 9))
                                Text(update.tagName)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(Color(.systemBlue))
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Button("Check Now") {
                            updateViewModel.checkNow()
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Display Page

    private var displayPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader("Display", subtitle: "Control what appears in the DAG list")

            settingsCard {
                Toggle("Show paused DAGs", isOn: $showPausedDAGs)
                    .font(.system(size: 12))
            }

            settingsCard {
                formField("DAG filter") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("regex pattern (optional)", text: $dagFilter)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: dagFilter) { _, newValue in validateRegex(newValue) }
                        if let err = regexValidationError {
                            Label(err, systemImage: "exclamationmark.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(.systemRed))
                        } else {
                            Text("Regex match on DAG IDs. Leave empty for all.")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Alerts Page

    private var alertsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader("Alerts", subtitle: "Get notified when DAG states change")

            settingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $notifyOnFailure) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Failure alerts")
                                .font(.system(size: 12))
                            Text("Notify when a DAG run fails")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Toggle(isOn: $notifyOnRecovery) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Recovery alerts")
                                .font(.system(size: 12))
                            Text("Notify when a failed DAG succeeds again")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Environments Page

    private var environmentsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            pageHeader("Environments", subtitle: "Configure your Airflow instances")

            // Environment list
            settingsCard {
                VStack(spacing: 0) {
                    ForEach(Array(editableEnvironments.enumerated()), id: \.element.id) { index, env in
                        envListRow(env: env, index: index)
                        if index < editableEnvironments.count - 1 {
                            Divider().padding(.leading, 30)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button(action: addEnvironment) {
                        Label("Add Environment", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                }
                .padding(.top, 6)
            }

            // Selected environment detail
            if selectedEnv != nil {
                envDetailSection
            }
        }
    }

    private func envListRow(env: EditableEnvironment, index: Int) -> some View {
        let isSelected = env.id == selectedEnvId
        return HStack(spacing: 10) {
            Circle()
                .fill(env.isEnabled ? Color(.systemGreen) : Color(.tertiaryLabelColor))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(env.name.isEmpty ? "Untitled" : env.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                if !env.baseURL.isEmpty {
                    Text(env.baseURL)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected && editableEnvironments.count > 1 {
                Button(action: { removeEnvironment(at: index) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.systemRed).opacity(0.7))
                }
                .buttonStyle(.borderless)
                .help("Remove environment")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.08) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedEnvId = env.id
                connectionTestState = .idle
                urlValidationError = nil
            }
        }
    }

    private var envDetailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Connection
            settingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        cardTitle("Connection")
                        Spacer()
                        Toggle("", isOn: envBinding(\.isEnabled, fallback: false))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        Text("Enabled")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    formField("Name") {
                        TextField("e.g. Production", text: envBinding(\.name, fallback: ""))
                            .textFieldStyle(.roundedBorder)
                    }

                    formField("URL") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("https://airflow.example.com", text: envBinding(\.baseURL, fallback: ""))
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: selectedEnv?.baseURL ?? "") { _, newValue in
                                    validateURL(newValue)
                                    connectionTestState = .idle
                                }
                            if let err = urlValidationError {
                                Label(err, systemImage: "exclamationmark.circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(.systemRed))
                            }
                        }
                    }
                }
            }

            // Authentication
            settingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    cardTitle("Authentication")

                    formField("Method") {
                        Picker("", selection: envBinding(\.authType, fallback: .basicAuth)) {
                            ForEach(EditableEnvironment.AuthType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                    }

                    if let env = selectedEnv {
                        switch env.authType {
                        case .basicAuth:
                            formField("Username") {
                                TextField("admin", text: envBinding(\.username, fallback: ""))
                                    .textFieldStyle(.roundedBorder)
                            }
                            formField("Password") {
                                SecureField("password", text: envBinding(\.password, fallback: ""))
                                    .textFieldStyle(.roundedBorder)
                            }
                        case .bearerToken:
                            formField("Token") {
                                SecureField("paste your token", text: envBinding(\.token, fallback: ""))
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    Label("Stored securely in macOS Keychain", systemImage: "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            // Test Connection
            HStack(spacing: 12) {
                Button(action: testConnection) {
                    HStack(spacing: 5) {
                        if connectionTestState == .testing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 9))
                        }
                        Text("Test Connection")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(connectionTestState == .testing || (selectedEnv?.baseURL.isEmpty ?? true))

                switch connectionTestState {
                case .idle, .testing:
                    EmptyView()
                case .success(let msg):
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.systemGreen))
                        .lineLimit(1)
                case .failure(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.systemRed))
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.systemRed))
                    .lineLimit(1)
            }
            Spacer()
            Button("Cancel") { closeWindow() }
                .keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Reusable Components

    private func pageHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    private func cardTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 75, alignment: .trailing)
            content()
        }
    }

    private func envBinding<T>(
        _ keyPath: WritableKeyPath<EditableEnvironment, T>,
        fallback: T
    ) -> Binding<T> {
        Binding(
            get: {
                guard let idx = selectedEnvIndex else { return fallback }
                return editableEnvironments[idx][keyPath: keyPath]
            },
            set: { newValue in
                guard let idx = selectedEnvIndex else { return }
                editableEnvironments[idx][keyPath: keyPath] = newValue
            }
        )
    }

    // MARK: - Actions

    private func addEnvironment() {
        let env = EditableEnvironment()
        editableEnvironments.append(env)
        selectedEnvId = env.id
        connectionTestState = .idle
    }

    private func removeEnvironment(at index: Int) {
        guard editableEnvironments.count > 1 else { return }
        let removedId = editableEnvironments[index].id
        editableEnvironments.remove(at: index)
        if selectedEnvId == removedId {
            selectedEnvId = editableEnvironments.first?.id
        }
        connectionTestState = .idle
    }

    private func loadCurrentConfig() {
        let config = configStore.config
        refreshInterval = config.refreshInterval
        showPausedDAGs = config.showPausedDAGs
        dagFilter = config.dagFilter ?? ""
        notifyOnFailure = config.notifications.onFailure
        notifyOnRecovery = config.notifications.onRecovery
        checkForUpdates = config.checkForUpdates

        if config.environments.isEmpty {
            let env = EditableEnvironment()
            editableEnvironments = [env]
            editableEnvironments[0].name = "Production"
            selectedEnvId = env.id
        } else {
            editableEnvironments = config.environments.map { EditableEnvironment(from: $0) }
            selectedEnvId = editableEnvironments.first?.id
        }
    }

    private func validateURL(_ urlString: String) {
        guard !urlString.isEmpty else { urlValidationError = nil; return }
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              let host = url.host, !host.isEmpty else {
            urlValidationError = "Must be a valid http:// or https:// URL"
            return
        }
        urlValidationError = nil
    }

    private func validateRegex(_ pattern: String) {
        guard !pattern.isEmpty else { regexValidationError = nil; return }
        do {
            _ = try NSRegularExpression(pattern: pattern)
            regexValidationError = nil
        } catch {
            regexValidationError = "Invalid regex: \(error.localizedDescription)"
        }
    }

    private func testConnection() {
        guard let env = selectedEnv, !env.baseURL.isEmpty else { return }
        connectionTestState = .testing

        let environment = AirflowEnvironment(
            id: env.id, name: env.name, baseURL: env.baseURL,
            credential: env.credential, isEnabled: true
        )

        Task {
            let client = AirflowAPIClient(environment: environment)
            let detectedVersion = await client.detectAPIVersion()
            await client.setAPIVersion(detectedVersion)

            do {
                let health = try await client.fetchHealth()
                let ver = detectedVersion == .v2 ? "v2" : "v1"
                connectionTestState = .success("\(health.isHealthy ? "Healthy" : "Unhealthy") (API \(ver))")
            } catch {
                do {
                    let dags = try await client.fetchDAGs()
                    let ver = detectedVersion == .v2 ? "v2" : "v1"
                    connectionTestState = .success("\(dags.totalEntries) DAGs (API \(ver))")
                } catch let e {
                    connectionTestState = .failure(e.localizedDescription)
                }
            }
        }
    }

    private func save() {
        saveError = nil

        for env in editableEnvironments {
            if !env.baseURL.isEmpty {
                guard let url = URL(string: env.baseURL),
                      let scheme = url.scheme,
                      ["http", "https"].contains(scheme.lowercased()),
                      let host = url.host, !host.isEmpty else {
                    saveError = "Invalid URL for \(env.name)"
                    return
                }
            }
        }

        if !dagFilter.isEmpty {
            if (try? NSRegularExpression(pattern: dagFilter)) == nil {
                saveError = "Invalid DAG filter regex"
                return
            }
        }

        let environments = editableEnvironments.map { e in
            AirflowEnvironment(
                id: e.id, name: e.name, baseURL: e.baseURL,
                credential: e.credential, isEnabled: e.isEnabled
            )
        }

        let config = AppConfig(
            environments: environments,
            refreshInterval: refreshInterval,
            showPausedDAGs: showPausedDAGs,
            dagFilter: dagFilter.isEmpty ? nil : dagFilter,
            notifications: NotificationSettings(
                onFailure: notifyOnFailure, onRecovery: notifyOnRecovery
            ),
            checkForUpdates: checkForUpdates
        )

        do {
            try configStore.save(config)
            onSave()
            closeWindow()
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}
