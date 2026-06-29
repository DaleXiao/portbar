import SwiftUI

struct SettingsView: View {
  @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
  @AppStorage("showMenuBarPortCount") private var showMenuBarPortCount = true

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Appearance")
          .font(.caption)
          .foregroundStyle(.secondary)

        AppearanceModeToggle(selection: $appearanceModeRaw)
      }

      Toggle("Show Port Count Next to Icon", isOn: $showMenuBarPortCount)

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text("About")
          .font(.caption)
          .foregroundStyle(.secondary)
        LabeledContent("App", value: AppInfo.name)
        LabeledContent("Version", value: AppInfo.version)
      }

      Spacer(minLength: 0)
    }
    .padding(20)
    .frame(width: 420, height: 240)
  }
}

private struct AppearanceModeToggle: View {
  @Binding var selection: String

  private let options: [AppAppearanceMode] = [.system, .day, .night]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(options) { mode in
        Button {
          withAnimation(.interpolatingSpring(stiffness: 260, damping: 22)) {
            selection = mode.rawValue
          }
        } label: {
          Image(systemName: mode.symbolName)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 38, height: 38)
            .foregroundStyle(selection == mode.rawValue ? .white : Color.primary.opacity(0.62))
            .background {
              if selection == mode.rawValue {
                Circle()
                  .fill(Color.accentColor)
                  .shadow(color: Color.accentColor.opacity(0.35), radius: 5, x: 0, y: 2)
              }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(mode.title)
        .accessibilityLabel(mode.title)
      }
    }
    .padding(5)
    .background {
      Capsule(style: .continuous)
        .fill(Color.primary.opacity(0.08))
      Capsule(style: .continuous)
        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
    }
    .frame(height: 48)
  }
}
