import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
  let store = PortStore()

  private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private var popover: NSPopover?
  private var cancellables = Set<AnyCancellable>()
  private let showMenuBarPortCountKey = "showMenuBarPortCount"

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    UserDefaults.standard.register(defaults: [
      "appearanceMode": AppAppearanceMode.system.rawValue,
      showMenuBarPortCountKey: true
    ])

    configureStatusItem()
    configurePopover()
    applyAppearance()
    observeStore()
    observePreferences()
  }

  private func configureStatusItem() {
    statusItem.autosaveName = "PortBar"
    statusItem.isVisible = true

    let image = NSImage(systemSymbolName: "network", accessibilityDescription: "PortBar")
      ?? NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "PortBar")
    image?.isTemplate = true

    statusItem.button?.image = image
    statusItem.button?.imagePosition = .imageLeading
    statusItem.button?.target = self
    statusItem.button?.action = #selector(togglePopover(_:))
    statusItem.button?.setAccessibilityLabel("PortBar")
    updateStatusItemTitle()
  }

  private func configurePopover() {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    popover.delegate = self
    let hostingController = NSHostingController(rootView: MenuBarDashboardView(store: store))
    hostingController.sizingOptions = [.preferredContentSize]
    popover.contentViewController = hostingController
    self.popover = popover
  }

  private func observeStore() {
    store.objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        DispatchQueue.main.async {
          self?.updateStatusItemTitle()
        }
      }
      .store(in: &cancellables)
  }

  private func observePreferences() {
    NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.applyAppearance()
        self?.updateStatusItemTitle()
      }
      .store(in: &cancellables)
  }

  @objc private func togglePopover(_ sender: Any?) {
    if popover?.isShown == true {
      closePopover()
    } else {
      openPopover()
    }
  }

  private func openPopover() {
    guard let button = statusItem.button, let popover else { return }
    applyAppearance()
    store.refreshNow()
    popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    popover.contentViewController?.view.window?.appearance = appearanceMode.nsAppearance
    NSApp.activate(ignoringOtherApps: true)
    button.highlight(true)
  }

  private func closePopover() {
    popover?.close()
    statusItem.button?.highlight(false)
  }

  private func updateStatusItemTitle() {
    let shouldShowCount = UserDefaults.standard.bool(forKey: showMenuBarPortCountKey)
    let title = shouldShowCount ? store.menuBarTitle : ""
    statusItem.button?.title = title.isEmpty ? "" : " \(title)"
    statusItem.button?.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
  }

  private func applyAppearance() {
    let appearance = appearanceMode.nsAppearance
    NSApp.appearance = appearance
    popover?.contentViewController?.view.window?.appearance = appearance
  }

  private var appearanceMode: AppAppearanceMode {
    AppAppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "") ?? .system
  }

  func popoverWillClose(_ notification: Notification) {
    statusItem.button?.highlight(false)
  }
}

@main
struct PortBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue

  var body: some Scene {
    Settings {
      SettingsView()
        .preferredColorScheme(appearanceMode.colorScheme)
    }
  }

  private var appearanceMode: AppAppearanceMode {
    AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
  }
}
