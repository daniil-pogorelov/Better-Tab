import Cocoa
import ServiceManagement // Required for Launch at Login
import Carbon.HIToolbox // For kAXTrustedCheckOptionPrompt and other constants
import os.log // Import for Unified Logging

// Define a log object for consistent logging within AppDelegate
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.example.BetterTab", category: "AppDelegate")

// The Principal Class setting in Info.plist handles the app entry point.
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var appSwitcherController: AppSwitcherController?
    private var preferencesWindowController: PreferencesWindowController?
    private var statusItem: NSStatusItem?

    // MARK: - Initialization
    override init() {
        super.init()
        os_log("AppDelegate init() called.", log: log, type: .debug)
    }


    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("applicationDidFinishLaunching starting...", log: log, type: .info)

        os_log("Initializing AppSwitcherController...", log: log, type: .debug)
        appSwitcherController = AppSwitcherController()

        os_log("Setting up Status Item...", log: log, type: .debug)
        setupStatusItem()

        os_log("Updating Login Item Status...", log: log, type: .debug)
        updateLoginItemStatus()

        os_log("Requesting Accessibility Permissions...", log: log, type: .debug)
        requestAccessibilityPermissions()

        os_log("Applying Theme Preference...", log: log, type: .debug)
         PreferencesManager.shared.applyThemePreference()

        os_log("applicationDidFinishLaunching finished.", log: log, type: .info)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        os_log("applicationWillTerminate", log: log, type: .info)
        appSwitcherController?.stopListening()
        os_log("App Will Terminate - event tap stopped.", log: log, type: .debug)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        // Use square length for icon-based items
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
             // Use an Image instead of Text
             if #available(macOS 11.0, *) {
                  // Choose a symbol that represents the app's function
                  let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular) // Adjust size/weight as needed
                  let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "BetterTab App Switcher")
                  button.image = image?.withSymbolConfiguration(symbolConfiguration) // Apply config here
                  button.image?.isTemplate = true // Allows automatic light/dark mode tinting
                  os_log("Set status item image to system symbol 'keyboard' with configuration.", log: log, type: .debug)
             } else {
                  // Fallback for older macOS
                  button.title = "BT" // Short text fallback
                  os_log("Set status item title to 'BT' (macOS < 11 fallback).", log: log, type: .debug)
             }

            button.action = #selector(statusItemClicked(_:))
            button.target = self
            os_log("Status item button created/updated with target self.", log: log, type: .debug)
        } else {
             os_log("FAILED to create status item button.", log: log, type: .error)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferencesWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit BetterTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        os_log("Status item menu created.", log: log, type: .debug)
    }

    // This action is primarily for the button itself, the menu appears automatically.
    @objc private func statusItemClicked(_ sender: Any?) {
        os_log("Status Item Button Clicked (menu should appear).", log: log, type: .debug)
    }

    // MARK: - Preferences

    @objc func openPreferencesWindow() {
        os_log("openPreferencesWindow action called.", log: log, type: .debug)
        if preferencesWindowController == nil {
            os_log("Creating new PreferencesWindowController.", log: log, type: .debug)
            preferencesWindowController = PreferencesWindowController()
        } else {
             os_log("Reusing existing PreferencesWindowController.", log: log, type: .debug)
        }
        preferencesWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true) // Ensure the app comes to the foreground
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil) // Ensure the window comes to the foreground
        os_log("Preferences window shown and brought to front.", log: log, type: .debug)
    }

    // MARK: - Launch at Login

    func updateLoginItemStatus() {
        let shouldLaunch = PreferencesManager.shared.launchAtLogin
        os_log("Attempting to update login item status. Should launch: %{public}@", log: log, type: .debug, String(describing: shouldLaunch))
        do {
            if #available(macOS 13.0, *) {
                if shouldLaunch {
                    try SMAppService.mainApp.register()
                    os_log("Successfully registered app for login (macOS 13+).", log: log, type: .info)
                } else {
                    try SMAppService.mainApp.unregister()
                    os_log("Successfully unregistered app from login (macOS 13+).", log: log, type: .info)
                }
            } else {
                // Fallback for older macOS versions
                // Note: SMLoginItemSetEnabled is deprecated but necessary for < macOS 13.
                // Ensure Constants.launcherAppBundleIdentifier is correctly set if using a helper app for older systems.
                // If not using a helper app, this might not work reliably or as expected on older systems.
                #if swift(>=5.7) // Check for Swift version that might have different deprecation warnings
                if !SMLoginItemSetEnabled(Constants.launcherAppBundleIdentifier as CFString, shouldLaunch) {
                     os_log("Failed to update login item status for older macOS using SMLoginItemSetEnabled.", log: log, type: .error)
                } else {
                     os_log("Updated login item status for older macOS: %{public}@", log: log, type: .info, String(describing: shouldLaunch))
                }
                #else
                // Handle older Swift versions if necessary, though this is unlikely to be an issue with modern Xcode
                os_log("SMLoginItemSetEnabled call skipped or needs adjustment for this Swift version on older macOS.", log: log, type: .warn)
                #endif
            }
        } catch {
            os_log("Error updating login item: %{public}@", log: log, type: .error, error.localizedDescription)
        }
    }

    // MARK: - Accessibility Permissions

    func requestAccessibilityPermissions() {
        os_log("Checking accessibility permissions...", log: log, type: .debug)
        // kAXTrustedCheckOptionPrompt is a CFString, so we use .takeUnretainedValue()
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        // The value should be a CFBoolean (kCFBooleanTrue or kCFBooleanFalse)
        let value = kCFBooleanTrue! // Prompt the user if not already trusted
        let options = [key: value] as CFDictionary
        
        os_log("Calling AXIsProcessTrustedWithOptions with prompt option.", log: log, type: .debug)
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        os_log("AXIsProcessTrustedWithOptions returned: %{public}@", log: log, type: .info, String(describing: isTrusted))

        if !isTrusted {
            os_log("Accessibility permissions NOT granted (or prompt dismissed). Showing alert.", log: log, type: .info)
            // Run on main thread as it's UI work
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "\(Bundle.main.localizedName ?? "BetterTab") needs Accessibility permissions to monitor keyboard input for the app switcher. Please grant access in System Settings > Privacy & Security > Accessibility."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    os_log("User chose to open System Settings for Accessibility.", log: log, type: .debug)
                    // Construct the URL for opening the Accessibility settings pane
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    } else {
                        os_log("Failed to create URL for Accessibility settings.", log: log, type: .error)
                    }
                } else {
                    os_log("User chose 'Later' for Accessibility permissions.", log: log, type: .debug)
                }
            }
        } else {
            os_log("Accessibility permissions ARE granted.", log: log, type: .info)
            os_log("Calling appSwitcherController.startListeningIfNeeded()", log: log, type: .debug)
            // Ensure controller is initialized before calling its methods
            appSwitcherController?.startListeningIfNeeded()
        }
    }
}

// Helper to get localized app name
extension Bundle {
    var localizedName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
