cask "airflow-bar" do
  version "0.1.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/maroil/airflow-bar/releases/download/v#{version}/AirflowBar-#{version}.dmg"
  name "AirflowBar"
  desc "macOS menu bar app for monitoring Apache Airflow DAGs"
  homepage "https://github.com/maroil/airflow-bar"

  depends_on macos: ">= :sonoma"

  app "AirflowBar.app"

  zap trash: [
    "~/Library/Preferences/com.marouane.AirflowBar.plist",
  ]
end
