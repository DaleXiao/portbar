import XCTest
@testable import PortBarCore

final class PortScannerTests: XCTestCase {
  func testParsesTcpFieldOutput() {
    let output = """
    p1548
    cnode
    u501
    Ldingxiao
    f26
    tIPv4
    PTCP
    n127.0.0.1:2026
    p785
    cControlCenter
    u501
    Ldingxiao
    f11
    tIPv4
    PTCP
    n*:7000
    """

    let entries = PortScanner.parseLsofFieldOutput(output, defaultTransport: .tcp)

    XCTAssertEqual(entries.count, 2)
    XCTAssertEqual(entries[0].port, 2026)
    XCTAssertEqual(entries[0].processName, "node")
    XCTAssertEqual(entries[0].scope, .loopback)
    XCTAssertEqual(entries[1].port, 7000)
    XCTAssertEqual(entries[1].scope, .allInterfaces)
  }

  func testFiltersConnectedUdpSocketsAndWildcardPorts() {
    let output = """
    p12765
    cBrowser Helper
    u501
    Ldingxiao
    f33
    tIPv4
    PUDP
    n192.168.3.173:60867->142.251.151.119:443
    f34
    tIPv4
    PUDP
    n*:*
    f60
    tIPv4
    PUDP
    n*:5353
    """

    let entries = PortScanner.parseLsofFieldOutput(output, defaultTransport: .udp)

    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].transport, .udp)
    XCTAssertEqual(entries[0].port, 5353)
    XCTAssertEqual(entries[0].scope, .allInterfaces)
  }

  func testDeduplicatesSameEndpointAcrossFileDescriptors() {
    let output = """
    p732
    crapportd
    u501
    Ldingxiao
    f10
    tIPv4
    PTCP
    n*:49152
    f11
    tIPv6
    PTCP
    n*:49152
    """

    let entries = PortScanner.parseLsofFieldOutput(output, defaultTransport: .tcp)

    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].processName, "rapportd")
    XCTAssertEqual(entries[0].port, 49152)
  }
}
