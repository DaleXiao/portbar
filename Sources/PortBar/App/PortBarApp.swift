import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
  let store = PortStore()

  private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private var popover: NSPopover?
  private let statusIconAnimator = StatusItemIconAnimator()
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
    observeAppCommands()
  }

  private func configureStatusItem() {
    statusItem.autosaveName = "PortBar"
    statusItem.isVisible = true

    let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "PortBar")
      ?? NSImage(systemSymbolName: "network", accessibilityDescription: "PortBar")
    image?.isTemplate = true

    statusItem.button?.image = image
    statusItem.button?.imagePosition = .imageLeading
    statusItem.button?.target = self
    statusItem.button?.action = #selector(togglePopover(_:))
    statusItem.button?.setAccessibilityLabel("PortBar")
    if let button = statusItem.button, let image {
      statusIconAnimator.attach(to: button, image: image)
    }
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

  private func observeAppCommands() {
    NotificationCenter.default.publisher(for: .portBarShowAboutPanel)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.showAboutPanel()
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

  private func showAboutPanel() {
    closePopover()
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [
      .applicationName: AppInfo.name,
      .applicationVersion: AppInfo.shortVersion
    ])
    NSApp.windows.first { $0.title == "About \(AppInfo.name)" }?.makeKeyAndOrderFront(nil)
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

private final class StatusItemIconAnimator: NSResponder {
  private weak var button: NSStatusBarButton?
  private var baseImage: NSImage?
  private var trackingArea: NSTrackingArea?
  private var animationTimer: Timer?
  private var animationFrames = [NSImage]()
  private var currentFrameIndex = 0
  private var remainingFrameAdvances = 0

  func attach(to button: NSStatusBarButton, image: NSImage) {
    self.button = button
    let size = normalizedSize(from: image.size)
    baseImage = makeGlobeFrame(size: size, phase: 0)
    animationFrames = makeAnimationFrames(size: size)
    button.image = baseImage
    installTrackingArea(on: button)
  }

  private func installTrackingArea(on button: NSStatusBarButton) {
    if let trackingArea {
      button.removeTrackingArea(trackingArea)
    }

    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    button.addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
  }

  override func mouseEntered(with event: NSEvent) {
    startAnimation()
  }

  override func mouseExited(with event: NSEvent) {
    stopAnimation()
  }

  private func startAnimation() {
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
    guard animationTimer == nil, !animationFrames.isEmpty else { return }

    currentFrameIndex = 0
    remainingFrameAdvances = animationFrames.count
    button?.image = baseImage

    let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
      self?.showNextFrame()
    }
    RunLoop.main.add(timer, forMode: .common)
    animationTimer = timer
  }

  private func stopAnimation() {
    animationTimer?.invalidate()
    animationTimer = nil
    currentFrameIndex = 0
    remainingFrameAdvances = 0
    button?.image = baseImage
  }

  private func showNextFrame() {
    guard remainingFrameAdvances > 0 else {
      stopAnimation()
      return
    }

    currentFrameIndex = (currentFrameIndex + 1) % animationFrames.count
    remainingFrameAdvances -= 1
    button?.image = animationFrames[currentFrameIndex]

    if remainingFrameAdvances == 0 {
      stopAnimation()
    }
  }

  private func makeAnimationFrames(size: NSSize) -> [NSImage] {
    let frameCount = 36
    return (0..<frameCount).map { index in
      makeGlobeFrame(size: size, phase: CGFloat(index) * 2 * .pi / CGFloat(frameCount))
    }
  }

  private func normalizedSize(from size: NSSize) -> NSSize {
    let side = max(16, min(size.width > 0 ? size.width : 18, size.height > 0 ? size.height : 18))
    return NSSize(width: side, height: side)
  }

  private func makeGlobeFrame(size: NSSize, phase: CGFloat) -> NSImage {
    let output = NSImage(size: size)
    output.isTemplate = true

    output.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let side = min(size.width, size.height)
    let lineWidth = max(1.0, side * 0.075)
    let inset = lineWidth / 2 + 0.75
    let globeRect = NSRect(
      x: (size.width - side) / 2 + inset,
      y: (size.height - side) / 2 + inset,
      width: side - inset * 2,
      height: side - inset * 2
    )

    drawLatitudeLines(in: globeRect, lineWidth: lineWidth)
    drawLongitudeLines(in: globeRect, phase: phase, lineWidth: lineWidth)
    drawGlobeOutline(in: globeRect, lineWidth: lineWidth)

    output.unlockFocus()

    return output
  }

  private func drawGlobeOutline(in rect: NSRect, lineWidth: CGFloat) {
    let outline = NSBezierPath(ovalIn: rect)
    outline.lineWidth = lineWidth
    NSColor.black.setStroke()
    outline.stroke()
  }

  private func drawLatitudeLines(in rect: NSRect, lineWidth: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: rect).addClip()

    NSColor.black.withAlphaComponent(0.52).setStroke()
    for latitude in [-0.48, 0, 0.48] as [CGFloat] {
      let y = rect.midY + rect.height * 0.5 * latitude
      let path = NSBezierPath()
      path.lineWidth = lineWidth * 0.82
      path.move(to: NSPoint(x: rect.minX, y: y))
      path.line(to: NSPoint(x: rect.maxX, y: y))
      path.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
  }

  private func drawLongitudeLines(in rect: NSRect, phase: CGFloat, lineWidth: CGFloat) {
    let longitudes = [-120, -60, 0, 60, 120, 180].map { CGFloat($0) * .pi / 180 }

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: rect).addClip()

    for longitude in longitudes {
      let angle = longitude + phase
      let depth = CGFloat(cos(Double(angle)))
      let alpha = depth >= 0 ? 0.86 : 0.26
      let path = longitudePath(in: rect, angle: angle)
      path.lineWidth = lineWidth * 0.82
      NSColor.black.withAlphaComponent(alpha).setStroke()
      path.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
  }

  private func longitudePath(in rect: NSRect, angle: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let radius = min(rect.width, rect.height) / 2
    let samples = 28
    let horizontalOffset = CGFloat(sin(Double(angle)))

    for index in 0...samples {
      let yProgress = -1 + 2 * CGFloat(index) / CGFloat(samples)
      let y = rect.midY + yProgress * radius
      let horizontalRadius = radius * CGFloat(sqrt(max(0, Double(1 - yProgress * yProgress))))
      let x = rect.midX + horizontalOffset * horizontalRadius
      let point = NSPoint(x: x, y: y)

      if index == 0 {
        path.move(to: point)
      } else {
        path.line(to: point)
      }
    }

    return path
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
