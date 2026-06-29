import Foundation

public enum PortTransport: String, CaseIterable, Sendable {
  case tcp = "TCP"
  case udp = "UDP"
}

public enum PortScope: String, Sendable {
  case allInterfaces
  case loopback
  case specificAddress

  public var title: String {
    switch self {
    case .allInterfaces: "All"
    case .loopback: "Loopback"
    case .specificAddress: "Host"
    }
  }
}

public struct PortEntry: Identifiable, Hashable, Sendable {
  public let transport: PortTransport
  public let port: Int
  public let endpoint: String
  public let scope: PortScope
  public let processName: String
  public let pid: Int
  public let userName: String?
  public let addressFamily: String?

  public var id: String {
    "\(transport.rawValue)-\(port)-\(pid)-\(processName)-\(endpoint)"
  }

  public init(
    transport: PortTransport,
    port: Int,
    endpoint: String,
    scope: PortScope,
    processName: String,
    pid: Int,
    userName: String?,
    addressFamily: String?
  ) {
    self.transport = transport
    self.port = port
    self.endpoint = endpoint
    self.scope = scope
    self.processName = processName
    self.pid = pid
    self.userName = userName
    self.addressFamily = addressFamily
  }
}
