import Foundation

public enum PortScannerError: LocalizedError {
  case lsofFailed(String)

  public var errorDescription: String? {
    switch self {
    case .lsofFailed(let message):
      message.isEmpty ? "Unable to read local ports with lsof." : message
    }
  }
}

public struct PortScanner: Sendable {
  private let lsofPath: String

  public init(lsofPath: String = "/usr/sbin/lsof") {
    self.lsofPath = lsofPath
  }

  public func scan() throws -> [PortEntry] {
    let tcpOutput = try runLsof(arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcuLnPt"])
    let udpOutput = try runLsof(arguments: ["-nP", "-iUDP", "-F", "pcuLnPt"])
    let entries = Self.parseLsofFieldOutput(tcpOutput, defaultTransport: .tcp)
      + Self.parseLsofFieldOutput(udpOutput, defaultTransport: .udp)
    return Self.sortedUnique(entries)
  }

  public static func parseLsofFieldOutput(
    _ output: String,
    defaultTransport: PortTransport? = nil,
    includeConnectedUDP: Bool = false
  ) -> [PortEntry] {
    var entries: [PortEntry] = []
    var currentPID: Int?
    var currentCommand = "Unknown"
    var currentUserName: String?
    var currentTransport = defaultTransport
    var currentAddressFamily: String?

    for rawLine in output.split(whereSeparator: \.isNewline) {
      guard let field = rawLine.first else { continue }
      let value = String(rawLine.dropFirst())

      switch field {
      case "p":
        currentPID = Int(value)
        currentCommand = "Unknown"
        currentUserName = nil
        currentTransport = defaultTransport
        currentAddressFamily = nil
      case "c":
        currentCommand = value.isEmpty ? "Unknown" : value
      case "L":
        currentUserName = value.isEmpty ? nil : value
      case "f":
        currentTransport = defaultTransport
        currentAddressFamily = nil
      case "P":
        currentTransport = PortTransport(rawValue: value.uppercased()) ?? defaultTransport
      case "t":
        currentAddressFamily = value.isEmpty ? nil : value
      case "n":
        guard let pid = currentPID,
          let transport = currentTransport,
          let endpoint = parseEndpoint(value, transport: transport, includeConnectedUDP: includeConnectedUDP)
        else {
          continue
        }

        entries.append(
          PortEntry(
            transport: transport,
            port: endpoint.port,
            endpoint: endpoint.displayName,
            scope: scope(for: endpoint.address),
            processName: currentCommand,
            pid: pid,
            userName: currentUserName,
            addressFamily: currentAddressFamily
          )
        )
      default:
        continue
      }
    }

    return sortedUnique(entries)
  }

  private func runLsof(arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: lsofPath)
    process.arguments = arguments

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    if process.terminationStatus != 0 {
      let trimmedError = error.trimmingCharacters(in: .whitespacesAndNewlines)
      if output.isEmpty, trimmedError.isEmpty {
        return ""
      }
      throw PortScannerError.lsofFailed(trimmedError)
    }

    return output
  }

  private static func parseEndpoint(
    _ name: String,
    transport: PortTransport,
    includeConnectedUDP: Bool
  ) -> (displayName: String, address: String, port: Int)? {
    if transport == .udp, !includeConnectedUDP, name.contains("->") {
      return nil
    }

    let localPart = name
      .split(separator: "->", maxSplits: 1, omittingEmptySubsequences: false)
      .first
      .map(String.init) ?? name
    let endpoint = localPart
      .replacingOccurrences(of: " (LISTEN)", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let separator = endpoint.lastIndex(of: ":") else {
      return nil
    }

    let portText = endpoint[endpoint.index(after: separator)...]
    guard let port = Int(portText) else {
      return nil
    }

    let address = String(endpoint[..<separator])
    return (endpoint, address, port)
  }

  private static func scope(for address: String) -> PortScope {
    let normalized = address
      .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
      .lowercased()

    switch normalized {
    case "*", "0.0.0.0", "::":
      return .allInterfaces
    case "127.0.0.1", "::1", "localhost":
      return .loopback
    default:
      return .specificAddress
    }
  }

  private static func sortedUnique(_ entries: [PortEntry]) -> [PortEntry] {
    var seen = Set<String>()
    let unique = entries.filter { entry in
      guard !seen.contains(entry.id) else {
        return false
      }
      seen.insert(entry.id)
      return true
    }

    return unique.sorted { left, right in
      if left.port != right.port {
        return left.port < right.port
      }
      if left.transport != right.transport {
        return left.transport.rawValue < right.transport.rawValue
      }
      if left.processName != right.processName {
        return left.processName.localizedCaseInsensitiveCompare(right.processName) == .orderedAscending
      }
      return left.pid < right.pid
    }
  }
}
