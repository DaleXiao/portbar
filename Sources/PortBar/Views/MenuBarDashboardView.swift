import AppKit
import PortBarCore
import SwiftUI

struct MenuBarDashboardView: View {
  @ObservedObject var store: PortStore
  @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
  @AppStorage("skipQuitConfirmation") private var skipQuitConfirmation = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var filterText = ""
  @State private var refreshIconRotation = 0.0
  @State private var settingsIconRotation = 0.0
  @State private var isSettingsPresented = false
  @State private var isQuitConfirmationPresented = false
  @State private var skipQuitConfirmationDraft = false
  @State private var isPortsExpanded = true
  @State private var expandedEntryIDs = Set<String>()

  private let columns = [
    GridItem(.flexible(), spacing: 8),
    GridItem(.flexible(), spacing: 8)
  ]

  var body: some View {
    dashboardPanel
      .padding(14)
      .frame(width: 360)
      .overlay {
        if isQuitConfirmationPresented {
          quitConfirmationOverlay
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
      }
      .environment(\.colorScheme, effectiveColorScheme)
      .preferredColorScheme(appearanceMode.colorScheme)
      .onDisappear {
        isSettingsPresented = false
        isQuitConfirmationPresented = false
      }
  }

  private var dashboardPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      summaryGrid

      if let errorMessage = store.errorMessage {
        ErrorBanner(message: errorMessage)
      }

      filterField
      portList
      footer
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 3) {
        Text("PortBar")
          .font(.headline)
        Text(store.statusText)
          .font(.caption)
          .foregroundStyle(store.errorMessage == nil ? Color.secondary : Color.orange)
      }
      Spacer()
      Button {
        requestQuit()
      } label: {
        Image(systemName: "power")
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .help("Quit")
    }
  }

  private var quitConfirmationOverlay: some View {
    ZStack {
      Rectangle()
        .fill(effectiveColorScheme == .dark ? Color.black.opacity(0.24) : Color.white.opacity(0.22))
        .contentShape(Rectangle())
        .onTapGesture {
          dismissQuitConfirmation()
        }

      QuitConfirmationDialog(
        isDoNotAskAgainSelected: $skipQuitConfirmationDraft,
        glassStyle: glassStyle,
        onCancel: dismissQuitConfirmation,
        onQuit: confirmQuit
      )
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .onTapGesture {}
    }
  }

  private var summaryGrid: some View {
    LazyVGrid(columns: columns, spacing: 8) {
      StatTile(
        systemImage: "number",
        title: "Ports",
        value: PortFormat.integer(store.summary.totalPorts),
        footnote: "Bound locally",
        glassStyle: glassStyle
      )
      StatTile(
        systemImage: "antenna.radiowaves.left.and.right",
        title: "TCP",
        value: PortFormat.integer(store.summary.tcpPorts),
        footnote: "Listening",
        glassStyle: glassStyle
      )
      StatTile(
        systemImage: "dot.radiowaves.left.and.right",
        title: "UDP",
        value: PortFormat.integer(store.summary.udpPorts),
        footnote: "Bound",
        glassStyle: glassStyle
      )
      StatTile(
        systemImage: "app.badge",
        title: "Apps",
        value: PortFormat.integer(store.summary.appCount),
        footnote: "Processes",
        glassStyle: glassStyle
      )
    }
  }

  private var filterField: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField("Filter app, port, PID", text: $filterText)
        .textFieldStyle(.plain)
    }
    .font(.caption)
    .padding(.horizontal, 9)
    .padding(.vertical, 7)
    .background {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(glassStyle.tileTint)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(glassStyle.tileBorder)
    }
  }

  private var portList: some View {
    VStack(alignment: .leading, spacing: 7) {
      Button {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
          isPortsExpanded.toggle()
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.primary)
            .rotationEffect(.degrees(isPortsExpanded ? 90 : 0))
            .frame(width: 10)
          Text("Ports")
            .font(.subheadline.weight(.semibold))
          Spacer()
          if !filteredEntries.isEmpty {
            Text("\(filteredEntries.count)")
              .font(.caption)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if isPortsExpanded {
        if store.isRefreshing, store.entries.isEmpty {
          EmptyStateView(title: "Scanning...", systemImage: "arrow.triangle.2.circlepath")
        } else if filteredEntries.isEmpty {
          EmptyStateView(title: filterText.isEmpty ? "No ports found" : "No matches", systemImage: "tray")
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 6) {
              ForEach(filteredEntries) { entry in
                PortRow(
                  entry: entry,
                  isExpanded: expansionBinding(for: entry),
                  glassStyle: glassStyle
                )
              }
            }
            .padding(.vertical, 1)
          }
          .frame(height: portsListHeight)
        }
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 14) {
      Spacer()

      Button {
        spinRefreshIcon()
        store.refreshNow()
      } label: {
        Image(systemName: "arrow.triangle.2.circlepath")
          .rotationEffect(.degrees(refreshIconRotation))
      }
      .disabled(store.isRefreshing)
      .help("Refresh")

      Button {
        spinSettingsIcon()
        isSettingsPresented.toggle()
      } label: {
        Image(systemName: "gearshape")
          .rotationEffect(.degrees(settingsIconRotation))
      }
      .help("Settings")
      .background {
        SettingsMenuPresenter(isPresented: $isSettingsPresented)
          .frame(width: 24, height: 24)
          .allowsHitTesting(false)
      }
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
  }

  private var filteredEntries: [PortEntry] {
    let trimmedFilter = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedFilter.isEmpty else {
      return store.entries
    }

    let query = trimmedFilter.lowercased()
    return store.entries.filter { entry in
      String(entry.port).contains(query)
        || String(entry.pid).contains(query)
        || entry.transport.rawValue.lowercased().contains(query)
        || entry.processName.lowercased().contains(query)
        || entry.endpoint.lowercased().contains(query)
        || (entry.userName?.lowercased().contains(query) ?? false)
    }
  }

  private var portsListHeight: CGFloat {
    let expandedCount = filteredEntries.filter { expandedEntryIDs.contains($0.id) }.count
    let compactRowsHeight = CGFloat(filteredEntries.count) * 48
    let detailsHeight = CGFloat(expandedCount) * 104
    return min(max(compactRowsHeight + detailsHeight, 120), 280)
  }

  private var appearanceMode: AppAppearanceMode {
    AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
  }

  private var effectiveColorScheme: ColorScheme {
    appearanceMode.colorScheme ?? AppAppearanceMode.systemColorScheme
  }

  private var glassStyle: AppGlassStyle {
    AppGlassStyle.current(mode: appearanceMode, colorScheme: effectiveColorScheme)
  }

  private func spinRefreshIcon() {
    guard !reduceMotion else { return }
    withAnimation(.linear(duration: 0.62)) {
      refreshIconRotation += 360
    }
  }

  private func spinSettingsIcon() {
    guard !reduceMotion else { return }
    withAnimation(.interpolatingSpring(stiffness: 260, damping: 18)) {
      settingsIconRotation += 90
    }
  }

  private func requestQuit() {
    if skipQuitConfirmation {
      NSApplication.shared.terminate(nil)
      return
    }

    isSettingsPresented = false
    skipQuitConfirmationDraft = false
    withAnimation(.easeOut(duration: 0.16)) {
      isQuitConfirmationPresented = true
    }
  }

  private func dismissQuitConfirmation() {
    skipQuitConfirmationDraft = false
    withAnimation(.easeOut(duration: 0.16)) {
      isQuitConfirmationPresented = false
    }
  }

  private func confirmQuit() {
    skipQuitConfirmation = skipQuitConfirmationDraft
    NSApplication.shared.terminate(nil)
  }

  private func expansionBinding(for entry: PortEntry) -> Binding<Bool> {
    Binding {
      expandedEntryIDs.contains(entry.id)
    } set: { isExpanded in
      if isExpanded {
        expandedEntryIDs.insert(entry.id)
      } else {
        expandedEntryIDs.remove(entry.id)
      }
    }
  }
}

private struct QuitConfirmationDialog: View {
  @Binding var isDoNotAskAgainSelected: Bool
  let glassStyle: AppGlassStyle
  let onCancel: () -> Void
  let onQuit: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      Image(nsImage: NSApplication.shared.applicationIconImage)
        .resizable()
        .scaledToFit()
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)

      VStack(spacing: 5) {
        Text("Quit PortBar?")
          .font(.headline)
        Text("PortBar will stop monitoring ports until you open it again.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }

      Button {
        isDoNotAskAgainSelected.toggle()
      } label: {
        HStack(spacing: 8) {
          ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(isDoNotAskAgainSelected ? Color.accentColor : Color.clear)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .strokeBorder(isDoNotAskAgainSelected ? Color.accentColor : Color.primary.opacity(0.55), lineWidth: 1.3)

            if isDoNotAskAgainSelected {
              Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
            }
          }
          .frame(width: 16, height: 16)

          Text("Don't ask again")
            .font(.caption)
            .foregroundStyle(.primary)

          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      HStack(spacing: 8) {
        Button("Cancel") {
          onCancel()
        }
        .keyboardShortcut(.cancelAction)

        Button("Quit", role: .destructive) {
          onQuit()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(16)
    .frame(width: 300)
    .background {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(glassStyle.panelTint)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(glassStyle.border)
    }
    .shadow(color: glassStyle.shadow, radius: 18, x: 0, y: 10)
  }
}

private struct SettingsMenuPresenter: NSViewRepresentable {
  @Binding var isPresented: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSView {
    NSView(frame: .zero)
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.isPresented = $isPresented

    if isPresented {
      DispatchQueue.main.async {
        context.coordinator.showMenu(from: nsView)
      }
    }
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.closeMenu()
  }

  @MainActor
  final class Coordinator: NSObject, NSMenuDelegate {
    var isPresented: Binding<Bool>?

    private let appearanceModeKey = "appearanceMode"
    private let showMenuBarPortCountKey = "showMenuBarPortCount"
    private var menu: NSMenu?
    private var isMenuOpen = false

    func showMenu(from view: NSView) {
      guard view.window != nil else { return }
      guard !isMenuOpen else { return }

      let menu = makeMenu()
      menu.delegate = self
      self.menu = menu
      isMenuOpen = true
      menu.popUp(positioning: nil, at: NSPoint(x: view.bounds.midX, y: view.bounds.maxY + 2), in: view)
    }

    func closeMenu() {
      menu?.cancelTracking()
      menu = nil
      isMenuOpen = false
    }

    func menuDidClose(_ menu: NSMenu) {
      isPresented?.wrappedValue = false
      isMenuOpen = false
      self.menu = nil
    }

    private func makeMenu() -> NSMenu {
      let menu = NSMenu(title: "Settings")
      menu.autoenablesItems = false

      let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
      let appearanceMenu = NSMenu(title: "Appearance")
      let currentMode = AppAppearanceMode(rawValue: UserDefaults.standard.string(forKey: appearanceModeKey) ?? "") ?? .system
      for mode in [AppAppearanceMode.day, .night, .system] {
        let item = NSMenuItem(title: mode.title, action: #selector(setAppearanceMode(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = mode.rawValue
        item.state = currentMode == mode ? .on : .off
        appearanceMenu.addItem(item)
      }
      menu.setSubmenu(appearanceMenu, for: appearanceItem)
      menu.addItem(appearanceItem)

      let launchItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin(_:)), keyEquivalent: "")
      launchItem.target = self
      launchItem.state = LaunchAtLoginService.isEnabled ? .on : .off
      menu.addItem(launchItem)

      let showPortCountItem = NSMenuItem(title: "Show Port Count", action: #selector(togglePortCount(_:)), keyEquivalent: "")
      showPortCountItem.target = self
      showPortCountItem.state = UserDefaults.standard.bool(forKey: showMenuBarPortCountKey) ? .on : .off
      menu.addItem(showPortCountItem)

      let aboutItem = NSMenuItem(title: "About PortBar", action: #selector(showAbout(_:)), keyEquivalent: "")
      aboutItem.target = self
      menu.addItem(aboutItem)

      return menu
    }

    @objc private func setAppearanceMode(_ item: NSMenuItem) {
      guard let rawValue = item.representedObject as? String else { return }
      let mode = AppAppearanceMode(rawValue: rawValue) ?? .system
      NSApp.appearance = mode.nsAppearance
      NSApp.keyWindow?.appearance = mode.nsAppearance
      UserDefaults.standard.set(rawValue, forKey: appearanceModeKey)
    }

    @objc private func toggleOpenAtLogin(_ item: NSMenuItem) {
      do {
        try LaunchAtLoginService.setEnabled(!LaunchAtLoginService.isEnabled)
      } catch {
        showErrorAlert(message: error.localizedDescription)
      }
    }

    @objc private func togglePortCount(_ item: NSMenuItem) {
      let isEnabled = UserDefaults.standard.bool(forKey: showMenuBarPortCountKey)
      UserDefaults.standard.set(!isEnabled, forKey: showMenuBarPortCountKey)
    }

    @objc private func showAbout(_ item: NSMenuItem) {
      NSApp.activate(ignoringOtherApps: true)
      NSApp.orderFrontStandardAboutPanel(options: [
        .applicationName: AppInfo.name,
        .applicationVersion: AppInfo.shortVersion
      ])
    }

    private func showErrorAlert(message: String) {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = AppInfo.name
      alert.informativeText = message
      alert.runModal()
    }
  }
}

private struct StatTile: View {
  let systemImage: String
  let title: String
  let value: String
  let footnote: String
  let glassStyle: AppGlassStyle

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .font(.caption.weight(.semibold))
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Text(value)
        .font(.title3.weight(.semibold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)

      Text(footnote)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(glassStyle.tileTint)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(glassStyle.tileBorder)
    }
  }
}

private struct PortRow: View {
  let entry: PortEntry
  @Binding var isExpanded: Bool
  let glassStyle: AppGlassStyle

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .center, spacing: 9) {
        Text("\(entry.port)")
          .font(.system(.body, design: .monospaced).weight(.semibold))
          .lineLimit(1)
          .frame(minWidth: 50, alignment: .leading)

        Text(entry.processName)
          .font(.subheadline)
          .lineLimit(1)
          .truncationMode(.tail)

        ProtocolBadge(transport: entry.transport)

        Spacer(minLength: 0)

        Button {
          var transaction = Transaction()
          transaction.disablesAnimations = true
          withTransaction(transaction) {
            isExpanded.toggle()
          }
        } label: {
          HStack(spacing: 4) {
            Text("Details")
            Image(systemName: "chevron.right")
              .font(.caption2.weight(.semibold))
              .rotationEffect(.degrees(isExpanded ? 90 : 0))
          }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(isExpanded ? "Hide Details" : "Show Details")
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 5) {
          PortDetailLine(label: "Endpoint", value: entry.endpoint)
          PortDetailLine(label: "PID", value: String(entry.pid))
          PortDetailLine(label: "User", value: entry.userName ?? "Unknown")
          PortDetailLine(label: "Family", value: entry.addressFamily ?? "Unknown")
          PortDetailLine(label: "Scope", value: entry.scope.title)
        }
        .padding(.leading, 59)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 8)
    .background {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(glassStyle.tileTint)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(glassStyle.tileBorder)
    }
  }
}

private struct PortDetailLine: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label)
        .foregroundStyle(.secondary)
        .frame(width: 52, alignment: .leading)
      Text(value)
        .foregroundStyle(.primary)
        .lineLimit(2)
        .truncationMode(.middle)
        .textSelection(.enabled)
    }
    .font(.caption2)
  }
}

private struct ProtocolBadge: View {
  let transport: PortTransport

  var body: some View {
    Text(transport.rawValue)
      .font(.caption2.weight(.semibold))
      .monospaced()
      .foregroundStyle(transport == .tcp ? Color.blue : Color.green)
      .frame(width: 34, height: 22)
      .background {
        Capsule(style: .continuous)
          .fill((transport == .tcp ? Color.blue : Color.green).opacity(0.12))
      }
  }
}

private struct EmptyStateView: View {
  let title: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: systemImage)
      Text(title)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
  }
}

private struct ErrorBanner: View {
  let message: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
      Text(message)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(.caption)
    .padding(9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.orange.opacity(0.12))
    }
  }
}
