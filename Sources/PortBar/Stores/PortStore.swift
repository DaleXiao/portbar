import Combine
import Foundation
import PortBarCore

struct PortSummary {
  let totalPorts: Int
  let tcpPorts: Int
  let udpPorts: Int
  let appCount: Int
}

@MainActor
final class PortStore: ObservableObject {
  @Published private(set) var entries: [PortEntry] = []
  @Published private(set) var isRefreshing = false
  @Published private(set) var lastRefreshDate: Date?
  @Published private(set) var errorMessage: String?

  private let scanner: PortScanner

  init(scanner: PortScanner = PortScanner()) {
    self.scanner = scanner
    refreshNow()
  }

  var summary: PortSummary {
    PortSummary(
      totalPorts: entries.count,
      tcpPorts: entries.filter { $0.transport == .tcp }.count,
      udpPorts: entries.filter { $0.transport == .udp }.count,
      appCount: Set(entries.map { "\($0.processName)#\($0.pid)" }).count
    )
  }

  var menuBarTitle: String {
    entries.isEmpty ? "" : "\(entries.count)"
  }

  var statusText: String {
    if isRefreshing {
      return "Scanning ports..."
    }
    if let lastRefreshDate {
      return "Updated at \(PortFormat.time(lastRefreshDate))"
    }
    return "Ready"
  }

  func refreshNow() {
    guard !isRefreshing else { return }
    isRefreshing = true
    errorMessage = nil

    Task {
      do {
        let scanner = scanner
        let scannedEntries = try await Task.detached(priority: .userInitiated) {
          try scanner.scan()
        }.value
        entries = scannedEntries
        lastRefreshDate = Date()
      } catch {
        errorMessage = error.localizedDescription
      }

      isRefreshing = false
    }
  }
}
