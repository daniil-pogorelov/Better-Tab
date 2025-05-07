import Cocoa
import Carbon.HIToolbox // For key codes and accessibility constants
import os.log // Import for Unified Logging

// Define a log object for consistent logging within AppSwitcherController
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.pogorielov.BetterTab", category: "AppSwitcherController")

class AppSwitcherController: NSObject {

    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isSwitcherActive = false
    private var typedString = "" // This is the source of the typed string for filtering
    private var runningAppsCache: [NSRunningApplication] = [] // Full list of running apps
    private var filteredApps: [NSRunningApplication] = [] // Apps after filtering by typedString
    private var selectedAppGlobalIndex: Int = 0 // Index in filteredApps
    
    private var overlayWindow: AppOverlayWindow?
    private var hideOverlayTimer: Timer?

    private var activationModifiersHeld = false
    private var activationTriggerKeyCode: Int = kVK_Tab

    private var appSpecificBindings: [AppBinding] = []

    private let maxVisibleItemsInSwitcher = AppOverlayWindow.getLayoutConstants().maxVisibleItemsInOverlay


    // MARK: - Initialization
    override init() {
        super.init()
        os_log("Initialized.", log: log, type: .info)

        activationTriggerKeyCode = PreferencesManager.shared.shortcutKeyCode
        os_log("Initial main shortcut key code loaded: %d", log: log, type: .debug, activationTriggerKeyCode)
        loadAppSpecificBindings()

        NotificationCenter.default.addObserver(self, selector: #selector(mainShortcutPreferenceDidChange), name: .shortcutPreferenceChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appBindingsDidChange), name: .appBindingsChanged, object: nil)
        os_log("Registered for shortcut and app binding change notifications.", log: log, type: .debug)
    }

    deinit {
        os_log("Deinitializing.", log: log, type: .info)
        NotificationCenter.default.removeObserver(self)
        stopListening()
    }

    // MARK: - Notification Handling
    @objc private func mainShortcutPreferenceDidChange() {
        os_log("Detected main shortcut preference change.", log: log, type: .debug)
        activationTriggerKeyCode = PreferencesManager.shared.shortcutKeyCode
        os_log("New main shortcut key code from prefs: %d", log: log, type: .debug, activationTriggerKeyCode)
    }

    @objc private func appBindingsDidChange() {
        os_log("Detected app bindings change.", log: log, type: .debug)
        loadAppSpecificBindings()
    }

    private func loadAppSpecificBindings() {
        appSpecificBindings = PreferencesManager.shared.appBindings
        os_log("Loaded %d app-specific bindings.", log: log, type: .info, appSpecificBindings.count)
    }

    // MARK: - Event Tap Management
    func startListeningIfNeeded() {
        os_log("startListeningIfNeeded called.", log: log, type: .debug)
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let value = kCFBooleanFalse
        let options = [key: value] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        os_log("Accessibility permission check (no prompt): %{public}@", log: log, type: .debug, String(describing: isTrusted))

        if isTrusted {
            if eventTap == nil {
                os_log("Permissions granted and event tap not running. Starting event tap.", log: log, type: .info)
                startEventTap()
            } else {
                os_log("Permissions granted, but event tap already running.", log: log, type: .debug)
            }
        } else {
            os_log("Permissions NOT granted. Event tap will not start. User should grant permissions via System Settings.", log: log, type: .default)
        }
    }

    private func startEventTap() {
        os_log("Attempting to start event tap.", log: log, type: .debug)
        guard eventTap == nil else {
            os_log("Event tap already started.", log: log, type: .info)
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                if let refcon = refcon {
                    let controller = Unmanaged<AppSwitcherController>.fromOpaque(refcon).takeUnretainedValue()
                    return controller.handleEvent(proxy: proxy, type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let createdTap = eventTap else {
            os_log("FAILED to create event tap!", log: log, type: .error)
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
        guard let createdRunLoopSource = runLoopSource else {
            os_log("FAILED to create run loop source!", log: log, type: .error)
            CGEvent.tapEnable(tap: createdTap, enable: false)
            self.eventTap = nil
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), createdRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: createdTap, enable: true)

        if CGEvent.tapIsEnabled(tap: createdTap) {
            os_log("Event Tap Started and Enabled Successfully.", log: log, type: .info)
        } else {
            os_log("Event Tap Started BUT FAILED TO ENABLE. This usually indicates a permissions issue or conflict.", log: log, type: .error)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), createdRunLoopSource, .commonModes)
            self.runLoopSource = nil
            self.eventTap = nil
        }
    }

    func stopListening() {
        os_log("stopListening called.", log: log, type: .debug)
        guard let tap = self.eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = self.runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            self.runLoopSource = nil
        }
        self.eventTap = nil
        os_log("Event Tap Stopped and resources released.", log: log, type: .info)
    }


    // MARK: - Event Handling Logic
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let nsEvent = NSEvent(cgEvent: event) else {
            os_log("Failed to convert CGEvent to NSEvent. Passing event through.", log: log, type: .default)
            return Unmanaged.passUnretained(event)
        }

        let currentRawFlags = nsEvent.modifierFlags
        var currentFlagsForComparison = currentRawFlags.intersection(.deviceIndependentFlagsMask)
        if currentFlagsForComparison.contains(.capsLock) { currentFlagsForComparison.remove(.capsLock) }
        let keyCode = Int(nsEvent.keyCode)

        if type == .keyDown {
            for binding in appSpecificBindings {
                guard binding.keyCode != -1 else { continue }
                var bindingModifiers = NSEvent.ModifierFlags(rawValue: binding.modifierFlags)
                if bindingModifiers.contains(.capsLock) { bindingModifiers.remove(.capsLock) }
                if currentFlagsForComparison == bindingModifiers && keyCode == binding.keyCode {
                    os_log("App-specific binding matched for: %{public}@", log: log, type: .info, binding.appName)
                    handleAppSpecificBinding(binding)
                    return nil
                }
            }
        }

        var mainSwitcherRequiredModifiers = PreferencesManager.shared.shortcutModifiers
        if mainSwitcherRequiredModifiers.contains(.capsLock) { mainSwitcherRequiredModifiers.remove(.capsLock) }
        let allowedExtraModifierForMainSwitcher = NSEvent.ModifierFlags.shift
        let essentialCurrentFlagsForMainSwitcher = currentFlagsForComparison.subtracting(allowedExtraModifierForMainSwitcher)
        let mainSwitcherModifiersAreCurrentlyHeld = (essentialCurrentFlagsForMainSwitcher == mainSwitcherRequiredModifiers)

        if mainSwitcherModifiersAreCurrentlyHeld != activationModifiersHeld {
            activationModifiersHeld = mainSwitcherModifiersAreCurrentlyHeld
            os_log("activationModifiersHeld state changed to: %{public}@", log: log, type: .debug, String(describing: activationModifiersHeld))
            if !activationModifiersHeld && isSwitcherActive {
                activateSelectedApp()
            } else if !activationModifiersHeld && !isSwitcherActive {
                resetTypedStringAndSelection()
            }
        }

        if type == .keyDown {
            if isSwitcherActive {
                if keyCode == kVK_Escape { hideSwitcher(); return nil }
                if activationModifiersHeld && keyCode == kVK_Tab {
                    cycleApps(forward: !currentRawFlags.contains(.shift)); return nil
                }
                // This is the type-to-filter logic (builds typedString)
                if activationModifiersHeld && keyCode != activationTriggerKeyCode && keyCode != kVK_Tab && keyCode != kVK_Escape {
                    if let chars = nsEvent.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty {
                        if chars.first?.isLetter ?? false || chars.first?.isNumber ?? false || chars == " " {
                            typedString += chars
                            os_log("Typed character for filtering: '%{public}@', new string: '%{private}@'", log: log, type: .debug, chars, typedString)
                            filterAppsAndUpdateOverlay()
                        } else if keyCode == kVK_Delete || keyCode == kVK_ForwardDelete {
                            if !typedString.isEmpty {
                                typedString.removeLast()
                                os_log("Delete/Backspace pressed. New string: '%{private}@'", log: log, type: .debug, typedString)
                                filterAppsAndUpdateOverlay()
                            }
                        }
                    }
                    return nil
                }
            } else {
                if activationModifiersHeld && keyCode == activationTriggerKeyCode { showSwitcher(); return nil }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - App Specific Binding Handling
    private func handleAppSpecificBinding(_ binding: AppBinding) {
        os_log("Handling app-specific binding for: %{public}@", log: log, type: .info, binding.appName)
        let runningAppInstances = NSRunningApplication.runningApplications(withBundleIdentifier: binding.appBundleIdentifier)
        if let appInstance = runningAppInstances.first {
            os_log("App '%{public}@' (PID: %d) is running. Attempting to activate...", log: log, type: .debug, binding.appName, appInstance.processIdentifier)
            NSApp.activate()
            let activationSuccess = appInstance.activate(options: [.activateAllWindows])
            os_log("Activation attempt for '%{public}@' returned: %{public}@", log: log, type: .info, binding.appName, String(describing: activationSuccess))
            if !activationSuccess {
                os_log("Activation FAILED for '%{public}@'. State: isActive=%{public}@, isHidden=%{public}@, isFinishedLaunching=%{public}@", log: log, type: .error, binding.appName, String(describing: appInstance.isActive), String(describing: appInstance.isHidden), String(describing: appInstance.isFinishedLaunching))
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: binding.appBundleIdentifier) {
                    let config = NSWorkspace.OpenConfiguration(); config.activates = true
                    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, err in
                        if err != nil { os_log("Fallback launch for '%{public}@' FAILED: %{public}@", log: log, type: .error, binding.appName, err!.localizedDescription) }
                        else { os_log("Fallback launch for '%{public}@' completed.", log: log, type: .info, binding.appName) }
                    }
                }
            }
        } else {
            os_log("App '%{public}@' not running. Attempting to launch.", log: log, type: .debug, binding.appName)
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: binding.appBundleIdentifier) {
                let config = NSWorkspace.OpenConfiguration(); config.activates = true
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, err in
                    if err != nil { os_log("Launch error for '%{public}@': %{public}@", log: log, type: .error, binding.appName, err!.localizedDescription) }
                    else { os_log("Launched '%{public}@'.", log: log, type: .info, binding.appName) }
                }
            } else { os_log("Could not get URL for %{public}@", log: log, type: .error, binding.appBundleIdentifier)}
        }
    }

    // MARK: - Main Switcher UI Management
    private func showSwitcher() {
        guard !isSwitcherActive else { return }
        os_log("Showing switcher...", log: log, type: .info)
        isSwitcherActive = true
        resetTypedStringAndSelection()
        fetchRunningApps()
        filterAppsAndUpdateOverlay()

        if overlayWindow == nil {
            os_log("Creating new AppOverlayWindow.", log: log, type: .debug)
            let (displayApps, displayIndex) = getDisplayAppsAndIndex()
            // *** This call now passes typedString ***
            overlayWindow = AppOverlayWindow(apps: displayApps, selectedIndex: displayIndex, typedString: typedString)
        }
        updateOverlay()
        
        overlayWindow?.center()
        overlayWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        hideOverlayTimer?.invalidate()
    }

    private func hideSwitcher() {
        guard isSwitcherActive else { return }
        os_log("Hiding switcher...", log: log, type: .info)
        hideOverlayTimer?.invalidate(); hideOverlayTimer = nil
        overlayWindow?.orderOut(nil)
        isSwitcherActive = false
        activationModifiersHeld = false
        resetTypedStringAndSelection()
    }

    private func resetTypedStringAndSelection() {
        typedString = "" // Ensure typedString is reset
        selectedAppGlobalIndex = 0
        os_log("Typed string and global selected app index reset.", log: log, type: .debug)
    }

    // MARK: - Main Switcher App Fetching and Filtering
    private func fetchRunningApps() {
        os_log("Fetching running applications...", log: log, type: .debug)
        runningAppsCache = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }
        os_log("Fetched %d running applications.", log: log, type: .debug, runningAppsCache.count)
    }
    
    private func filterAppsAndUpdateOverlay() {
        os_log("Filtering apps based on typed string: '%{private}@'", log: log, type: .debug, typedString)
        if typedString.isEmpty {
            filteredApps = runningAppsCache
        } else {
            let useFuzzySearch = PreferencesManager.shared.fuzzySearchEnabled
            let lowercasedTypedString = typedString.lowercased()
            filteredApps = runningAppsCache.filter { app in
                guard let appName = app.localizedName?.lowercased() else { return false }
                return useFuzzySearch ? appName.contains(lowercasedTypedString) : appName.hasPrefix(lowercasedTypedString)
            }
        }

        if filteredApps.isEmpty {
            selectedAppGlobalIndex = 0
        } else if selectedAppGlobalIndex >= filteredApps.count {
            selectedAppGlobalIndex = 0
        }
        
        os_log("Filtered apps count: %d. Global selected index: %d.", log: log, type: .debug, filteredApps.count, selectedAppGlobalIndex)
        
        if isSwitcherActive {
            updateOverlay()
        }
    }
    
    // MARK: - "Sliding Window" Logic and Overlay Update
    private func getDisplayAppsAndIndex() -> (appsToDisplay: [NSRunningApplication], selectedIndexInDisplay: Int) {
        guard !filteredApps.isEmpty else { return ([], 0) }
        let totalFilteredCount = filteredApps.count
        if totalFilteredCount <= maxVisibleItemsInSwitcher { return (filteredApps, selectedAppGlobalIndex) }
        var startIndex = selectedAppGlobalIndex - (maxVisibleItemsInSwitcher / 2)
        startIndex = max(0, startIndex)
        startIndex = min(startIndex, totalFilteredCount - maxVisibleItemsInSwitcher)
        let endIndex = min(startIndex + maxVisibleItemsInSwitcher, totalFilteredCount)
        let appsToDisplay = Array(filteredApps[startIndex..<endIndex])
        let selectedIndexInDisplay = selectedAppGlobalIndex - startIndex
        os_log("Sliding window: Total=%d, GlobalSel=%d, MaxVis=%d -> Displaying %d (%d..<%d), SelInDisplay=%d", log: log, type: .debug, totalFilteredCount, selectedAppGlobalIndex, maxVisibleItemsInSwitcher, appsToDisplay.count, startIndex, endIndex, selectedIndexInDisplay)
        return (appsToDisplay, selectedIndexInDisplay)
    }

    private func updateOverlay() {
        guard isSwitcherActive, let currentOverlayWindow = overlayWindow else { return }
        let (displayApps, displayIndex) = getDisplayAppsAndIndex()
        // *** This call now passes typedString ***
        currentOverlayWindow.update(apps: displayApps, selectedIndex: displayIndex, typedString: typedString)
    }

    // MARK: - Main Switcher App Cycling and Activation
    private func cycleApps(forward: Bool) {
        guard !filteredApps.isEmpty else { return }
        if forward { selectedAppGlobalIndex = (selectedAppGlobalIndex + 1) % filteredApps.count }
        else { selectedAppGlobalIndex = (selectedAppGlobalIndex - 1 + filteredApps.count) % filteredApps.count }
        os_log("Cycled apps. New global selected index: %d", log: log, type: .debug, selectedAppGlobalIndex)
        updateOverlay()
    }

    private func activateSelectedApp() {
        hideOverlayTimer?.invalidate(); hideOverlayTimer = nil
        guard !filteredApps.isEmpty, selectedAppGlobalIndex >= 0, selectedAppGlobalIndex < filteredApps.count else {
            if isSwitcherActive { hideSwitcher() }
            return
        }
        let appToActivate = filteredApps[selectedAppGlobalIndex]
        os_log("Activating selected app: %{public}@", log: log, type: .info, appToActivate.localizedName ?? "Unknown")
        let wasActive = isSwitcherActive
        isSwitcherActive = false
        activationModifiersHeld = false
        overlayWindow?.orderOut(nil)
        NSApp.activate()
        let activationSuccess = appToActivate.activate(options: [.activateAllWindows])
        os_log("Activation attempt for '%{public}@' returned: %{public}@", log: log, type: .info, appToActivate.localizedName ?? "Unknown", String(describing: activationSuccess))
        if !activationSuccess {
            os_log("Activation FAILED for '%{public}@'.", log: log, type: .error, appToActivate.localizedName ?? "Unknown")
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appToActivate.bundleIdentifier ?? "") {
                let config = NSWorkspace.OpenConfiguration(); config.activates = true
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, err in
                    if err != nil { os_log("Fallback launch failed: %{public}@", log: log, type: .error, err!.localizedDescription) }
                    else { os_log("Fallback launch completed.", log: log, type: .info) }
                }
            }
        }
        if wasActive && self.overlayWindow?.isVisible ?? false { os_log("Post-activation cleanup.", log: log, type: .debug) }
        resetTypedStringAndSelection()
    }
}
