import Cocoa
import os.log // Import for Unified Logging

// Define a log object for consistent logging
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.pogorielov.BetterTab", category: "PreferencesWindowController")

// --- Manages the Preferences Window (Now with Tabs and Icons) ---
class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    // MARK: - Initialization

    convenience init() {
        os_log("Initializing PreferencesWindowController...", log: log, type: .debug)
        // Create a window sized appropriately for tabbed content
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400), // Adjusted size for more tabs
            styleMask: [.titled, .closable, .miniaturizable], // Standard window style
            backing: .buffered,
            defer: false)
        window.center() // Center the window on screen
        window.title = "BetterTab Preferences"
        window.isReleasedWhenClosed = false // Keep controller alive when window is closed, so it can be reshown

        self.init(window: window)
        os_log("NSWindow created and self.init(window:) called.", log: log, type: .debug)

        // --- Setup Tab View Controller ---
        let tabViewController = NSTabViewController()
        os_log("NSTabViewController created.", log: log, type: .debug)

        // Create instances of the view controllers for each tab
        let generalVC = GeneralPreferencesViewController()
        generalVC.title = "General" // Title for the tab, also used by NSTabViewItem if no image

        let appearanceVC = AppearancePreferencesViewController()
        appearanceVC.title = "Appearance"

        let bindsVC = BindsViewController()
        bindsVC.title = "App Binds" // Renamed in original code

        os_log("Preference ViewControllers (General, Appearance, Binds) instantiated.", log: log, type: .debug)

        // Create NSTabViewItems for each ViewController
        let generalTabViewItem = NSTabViewItem(viewController: generalVC)
        let appearanceTabViewItem = NSTabViewItem(viewController: appearanceVC)
        let bindsTabViewItem = NSTabViewItem(viewController: bindsVC)

        // --- Add Icons to TabViewItems (macOS 11+ for SF Symbols) ---
        if #available(macOS 11.0, *) {
            generalTabViewItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General Settings")
            appearanceTabViewItem.image = NSImage(systemSymbolName: "paintbrush", accessibilityDescription: "Appearance Settings")
            bindsTabViewItem.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "App Binds Settings")
            os_log("SF Symbols set for TabViewItems (macOS 11+).", log: log, type: .debug)
        } else {
            os_log("SF Symbols for TabViewItems not available on this macOS version (pre-11). Titles will be used.", log: log, type: .info)
        }

        // Add the tab view items to the tab view controller
        // The order here determines the order of tabs.
        tabViewController.addTabViewItem(generalTabViewItem)
        tabViewController.addTabViewItem(appearanceTabViewItem)
        tabViewController.addTabViewItem(bindsTabViewItem)
        os_log("TabViewItems added to NSTabViewController.", log: log, type: .debug)

        // Set the tab style (e.g., .toolbar, .segmentedControl, .unspecified)
        // .toolbar is common for preferences windows.
        tabViewController.tabStyle = .toolbar
        os_log("NSTabViewController tabStyle set to .toolbar.", log: log, type: .debug)
        
        // Ensure the tab view controller resizes with the window if the window is made resizable
        // (though current styleMask doesn't include .resizable)
        tabViewController.view.autoresizingMask = [.width, .height]


        // Set the tab view controller as the window's content view controller
        self.contentViewController = tabViewController
        self.window?.delegate = self // Set self as window delegate to receive window events

        os_log("PreferencesWindowController Initialized successfully with Tabs and Icons.", log: log, type: .info)
    }

    // MARK: - NSWindowController Lifecycle

    override func windowDidLoad() {
        super.windowDidLoad()
        os_log("Preferences Window Did Load.", log: log, type: .info)
        // You can set the initially selected tab if needed, for example:
        // if let tabVC = self.contentViewController as? NSTabViewController {
        //     tabVC.selectedTabViewItemIndex = 0 // Select the first tab (General)
        //     os_log("Initially selected tab index set to 0 (General).", log: log, type: .debug)
        // }
    }

    // MARK: - NSWindowDelegate Methods

    func windowWillClose(_ notification: Notification) {
        os_log("Preferences Window Will Close.", log: log, type: .info)
        // Perform any cleanup if necessary when the window is about to close.
        // Since isReleasedWhenClosed is false, the controller itself won't be deallocated here.
    }

    // MARK: - Show Window Override

    // Override showWindow to ensure it comes to the front and activates the app.
    override func showWindow(_ sender: Any?) {
        os_log("showWindow called. Making window key and ordering front.", log: log, type: .debug)
        super.showWindow(sender)
        self.window?.makeKeyAndOrderFront(sender) // Bring the window to the front
        NSApp.activate() // Activate the application itself
        os_log("Preferences Window Shown. App activated.", log: log, type: .info)
    }
}
