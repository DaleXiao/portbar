import Foundation

enum AppInfo {
  static let name = "PortBar"

  static var shortVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.1"
  }

  static var version: String {
    shortVersion
  }
}

extension Notification.Name {
  static let portBarShowAboutPanel = Notification.Name("portBarShowAboutPanel")
}
