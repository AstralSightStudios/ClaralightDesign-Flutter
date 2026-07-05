import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let mobileLayoutWidthBreakpoint: CGFloat = 768.0

  private var resizeObserver: NSObjectProtocol?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame
    // Give the gallery enough height for full-size component demos. State
    // restoration would shrink the window back after launch, so opt out.
    self.isRestorable = false
    if windowFrame.height < 920, let screen = self.screen ?? NSScreen.main {
      windowFrame.size = NSSize(width: max(windowFrame.width, 880), height: 920)
      windowFrame.origin.y = max(screen.visibleFrame.minY, screen.visibleFrame.maxY - 940)
    }
    adoptTahoeLiquidGlassChrome(using: flutterViewController)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  deinit {
    if let resizeObserver {
      NotificationCenter.default.removeObserver(resizeObserver)
    }
  }

  private func adoptTahoeLiquidGlassChrome(using flutterViewController: FlutterViewController) {
    var targetContentSize = frame.size
    targetContentSize.width = max(targetContentSize.width, 600.0)
    targetContentSize.height = max(targetContentSize.height, 400.0)

    let toolbar = NSToolbar(identifier: "TahoeLiquidGlassToolbar")
    toolbar.showsBaselineSeparator = false
    self.toolbar = toolbar

    let sidebarViewController = NSViewController()
    let sidebarView = NSView()
    sidebarView.wantsLayer = true
    sidebarViewController.view = sidebarView
    sidebarView.widthAnchor.constraint(greaterThanOrEqualToConstant: 1.0).isActive = true

    let splitViewController = NSSplitViewController()
    let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
    let detailItem = NSSplitViewItem(viewController: flutterViewController)
    splitViewController.addSplitViewItem(sidebarItem)
    splitViewController.addSplitViewItem(detailItem)
    sidebarItem.isCollapsed = true

    contentViewController = splitViewController
    setContentSize(targetContentSize)
    contentMinSize = NSSize(width: 480.0, height: 320.0)

    styleMask.insert(.fullSizeContentView)
    if #available(macOS 11.0, *) {
      toolbarStyle = .unified
    }
    titleVisibility = .hidden
    titlebarAppearsTransparent = true

    installResizeChromeToggle()

    let rootView = splitViewController.view
    rootView.translatesAutoresizingMaskIntoConstraints = true
    if let contentView {
      rootView.frame = contentView.bounds
    }
    rootView.autoresizingMask = [.width, .height]
    rootView.needsLayout = true
    rootView.layoutSubtreeIfNeeded()
  }

  private func installResizeChromeToggle() {
    applyWindowChromeForCurrentWidth()

    resizeObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didResizeNotification,
      object: self,
      queue: nil
    ) { [weak self] _ in
      self?.applyWindowChromeForCurrentWidth()
    }
  }

  private func applyWindowChromeForCurrentWidth() {
    let useMobileChrome = frame.width <= Self.mobileLayoutWidthBreakpoint

    if useMobileChrome {
      styleMask.remove(.fullSizeContentView)
    } else {
      styleMask.insert(.fullSizeContentView)
    }

    if #available(macOS 11.0, *) {
      toolbarStyle = useMobileChrome ? .automatic : .unified
    }

    titlebarAppearsTransparent = !useMobileChrome
    titleVisibility = useMobileChrome ? .visible : .hidden

    // Keeping the toolbar attached is what lets Tahoe use the newer rounded chrome.
    toolbar?.isVisible = !useMobileChrome
  }
}
