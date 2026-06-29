import SwiftUI

struct AppGlassStyle {
  let panelTint: Color
  let tileTint: Color
  let border: Color
  let tileBorder: Color
  let shadow: Color

  static func current(mode: AppAppearanceMode, colorScheme: ColorScheme) -> AppGlassStyle {
    switch mode {
    case .day:
      return AppGlassStyle(
        panelTint: Color.white.opacity(0.28),
        tileTint: Color.white.opacity(0.13),
        border: Color.white.opacity(0.36),
        tileBorder: Color.black.opacity(0.11),
        shadow: Color.black.opacity(0.08)
      )
    case .night:
      return AppGlassStyle(
        panelTint: Color.black.opacity(0.22),
        tileTint: Color.white.opacity(0.055),
        border: Color.white.opacity(0.14),
        tileBorder: Color.white.opacity(0.13),
        shadow: Color.black.opacity(0.22)
      )
    case .system:
      if colorScheme == .dark {
        return AppGlassStyle(
          panelTint: Color.black.opacity(0.18),
          tileTint: Color.white.opacity(0.05),
          border: Color.white.opacity(0.14),
          tileBorder: Color.white.opacity(0.13),
          shadow: Color.black.opacity(0.20)
        )
      }
      return AppGlassStyle(
        panelTint: Color.white.opacity(0.24),
        tileTint: Color.white.opacity(0.12),
        border: Color.white.opacity(0.34),
        tileBorder: Color.black.opacity(0.10),
        shadow: Color.black.opacity(0.07)
      )
    }
  }
}
