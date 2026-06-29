import Foundation

enum PortFormat {
  static func integer(_ value: Int) -> String {
    value.formatted(.number.grouping(.automatic))
  }

  static func time(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
  }
}
