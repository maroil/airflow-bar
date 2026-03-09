import Foundation

public enum AirflowWebURL: Sendable {
    public static func home(baseURL: String) -> URL? {
        build(baseURL: baseURL, pathComponents: ["home"])
    }

    public static func dagGrid(baseURL: String, dagId: String) -> URL? {
        build(baseURL: baseURL, pathComponents: ["dags", dagId, "grid"])
    }

    private static func build(baseURL: String, pathComponents: [String]) -> URL? {
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }

        let existingPath = components.path
            .split(separator: "/")
            .map(String.init)
        let encodedPath = (existingPath + pathComponents)
            .map(encodePathComponent)
            .joined(separator: "/")

        components.percentEncodedPath = "/" + encodedPath
        return components.url
    }

    private static func encodePathComponent(_ component: String) -> String {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/")
        return component.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? component
    }
}
