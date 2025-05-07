import Cocoa
import ServiceManagement // For Launch at Login checkbox action (though PreferencesManager handles the call)
import Carbon.HIToolbox // For key constants
import os.log // Import for Unified Logging

// Define a log object for consistent logging
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.pogorielov.BetterTab", category: "GeneralPreferencesViewController")

// --- Manages the UI Controls within the "General" Preferences Tab ---
class GeneralPreferencesViewController: NSViewController {

    // MARK: - UI Elements

    private lazy var fuzzySearchCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "Enable Fuzzy Search (App Switcher)", target: self, action: #selector(fuzzySearchChanged(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        return checkbox
    }()

    private lazy var launchAtLoginCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "Launch App at Login", target: self, action: #selector(launchAtLoginChanged(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        return checkbox
    }()

    // Theme UI elements were removed from this VC in the user-provided code,
    // as they are now in AppearancePreferencesViewController.

    private lazy var shortcutLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Main Shortcut:")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var currentShortcutLabel: NSTextField = {
        let label = NSTextField(labelWithString: "") // Initial text set in loadPreferences/updateShortcutDisplay
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false // Typically, users don't select this; they record.
        label.isBezeled = true
        label.bezelStyle = .roundedBezel
        label.backgroundColor = .windowBackgroundColor // Or .textBackgroundColor for a slightly different look
        return label
    }()

    private lazy var changeShortcutButton: NSButton = {
        let button = NSButton(title: "Change...", target: self, action: #selector(changeShortcutClicked(_:)))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.toolTip = "Click to record a new shortcut for the main app switcher"
        return button
    }()

    // State for shortcut recording
    private var isRecordingShortcut = false
    private var shortcutMonitor: Any? // Holds the NSEvent local monitor

    // Main stack view for layout
    private lazy var stackView: NSStackView = {
        let views: [NSView] = [
            fuzzySearchCheckbox,
            launchAtLoginCheckbox,
            createShortcutRow() // Helper method to create the shortcut UI row
        ]
        let stack = NSStackView(views: views)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading // Align content to the leading edge
        stack.distribution = .fill // Let stack view manage distribution if needed, though spacing is primary
        stack.spacing = 15 // Spacing between preference items
        return stack
    }()


    // MARK: - View Lifecycle

    override func loadView() {
        // Frame size based on the original file, adjusted for removed theme settings
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 150))
        os_log("View Loaded.", log: log, type: .debug)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("View Did Load.", log: log, type: .debug)
        setupUI()
        loadPreferences()
        // It's good practice to also observe if preferences change externally,
        // though for this VC, viewWillAppear often handles re-syncing.
        // NotificationCenter.default.addObserver(self, selector: #selector(preferencesDidChange), name: .shortcutPreferenceChanged, object: nil)
        // NotificationCenter.default.addObserver(self, selector: #selector(preferencesDidChange), name: .launchAtLoginPreferenceChanged, object: nil) // If specific notifications are posted
    }
    
    // Deinit to clean up observers if any were added directly here.
    // deinit {
    //     NotificationCenter.default.removeObserver(self)
    //     os_log("Deinitialized and observers removed.", log: log, type: .debug)
    // }

    override func viewWillAppear() {
        super.viewWillAppear()
        os_log("View Will Appear. Updating shortcut display.", log: log, type: .debug)
        // Refresh UI elements that might have changed, especially the shortcut display.
        loadPreferences() // Reload all relevant preferences for this tab
    }

     override func viewWillDisappear() {
         super.viewWillDisappear()
         os_log("View Will Disappear. Stopping shortcut recording if active.", log: log, type: .debug)
         // Ensure shortcut recording is stopped if the view disappears.
         stopRecordingShortcut(save: false) // Don't save if view just disappears
     }

    // MARK: - UI Setup

    private func setupUI() {
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            // Allow stack view to determine its own bottom, or constrain if needed.
            // stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
        os_log("UI Setup Complete.", log: log, type: .debug)
    }

     private func createShortcutRow() -> NSView {
         let shortcutStack = NSStackView(views: [
             shortcutLabel,
             currentShortcutLabel,
             changeShortcutButton
         ])
         shortcutStack.orientation = .horizontal
         shortcutStack.spacing = 8 // Standard spacing

         // Define hugging priorities to control how views resize or resist resizing.
         // Lower priority means more likely to expand. Higher means more likely to shrink or stay fixed.
         shortcutStack.setHuggingPriority(.defaultLow, for: .horizontal) // Allow stack to expand if window resizes
         shortcutLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal) // "Main Shortcut:" label should not stretch much
         currentShortcutLabel.setContentHuggingPriority(.defaultLow, for: .horizontal) // Allow current shortcut label to stretch
         changeShortcutButton.setContentHuggingPriority(.defaultHigh, for: .horizontal) // "Change..." button should not stretch

         // Ensure currentShortcutLabel has a minimum sensible width
         currentShortcutLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
         return shortcutStack
     }

    // MARK: - Load and Save Preferences

    private func loadPreferences() {
        os_log("Loading preferences into UI.", log: log, type: .debug)
        fuzzySearchCheckbox.state = PreferencesManager.shared.fuzzySearchEnabled ? .on : .off
        launchAtLoginCheckbox.state = PreferencesManager.shared.launchAtLogin ? .on : .off
        updateShortcutDisplay()
    }

    private func updateShortcutDisplay() {
        let shortcutString = PreferencesManager.shared.getShortcutDisplayString()
        currentShortcutLabel.stringValue = shortcutString
        os_log("Shortcut display updated to: %{public}@", log: log, type: .debug, shortcutString)
    }

    // MARK: - Action Methods

    @objc private func fuzzySearchChanged(_ sender: NSButton) {
        let isEnabled = (sender.state == .on)
        PreferencesManager.shared.fuzzySearchEnabled = isEnabled
        os_log("Fuzzy Search checkbox changed. New state: %{public}@", log: log, type: .info, String(describing: isEnabled))
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let isEnabled = (sender.state == .on)
        PreferencesManager.shared.launchAtLogin = isEnabled
        os_log("Launch at Login checkbox changed. New state: %{public}@", log: log, type: .info, String(describing: isEnabled))
        // PreferencesManager's setter for launchAtLogin will call AppDelegate's updateLoginItemStatus.
    }

    @objc private func changeShortcutClicked(_ sender: NSButton) {
        os_log("Change Shortcut button clicked. Current recording state: %{public}@", log: log, type: .debug, String(describing: isRecordingShortcut))
        if isRecordingShortcut {
            stopRecordingShortcut(save: false) // If already recording, clicking again cancels.
        } else {
            startRecordingShortcut()
        }
    }

    // MARK: - Shortcut Recording

    private func startRecordingShortcut() {
        os_log("Starting shortcut recording...", log: log, type: .info)
        isRecordingShortcut = true
        changeShortcutButton.title = "Stop Recording" // Update button title
        currentShortcutLabel.stringValue = "Type new shortcut..."
        currentShortcutLabel.textColor = .keyboardFocusIndicatorColor // Provide visual feedback

        // Make the view first responder to capture key events directly if needed,
        // though local monitor is more robust for system-wide shortcuts.
        // view.window?.makeFirstResponder(view) // Usually not needed with addLocalMonitorForEvents

        // Add a local event monitor for keyDown events.
        // This captures key presses while this view (or its window) is active.
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self, self.isRecordingShortcut else {
                // If not recording or self is nil, pass the event through.
                return event
            }

            // Ignore modifier-only key presses (e.g., just pressing Shift).
            if event.isModifierOnly {
                os_log("Shortcut recording: Modifier key pressed alone. Ignoring.", log: log, type: .debug)
                return event // Pass through modifier-only events for other system behaviors
            }

            // Check for required modifiers (Command, Control, or Option).
            // This is a policy decision; you might allow shortcuts without these.
            let requiredModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            let pressedModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if pressedModifiers.intersection(requiredModifiers).isEmpty && !pressedModifiers.isEmpty {
                 // If some modifiers are pressed, but none are Cmd, Ctrl, or Opt (e.g., just Shift + A)
                 // This is a soft warning; the shortcut might still be saved.
                 os_log("Shortcut recording: New shortcut does not include Command, Control, or Option. Displaying hint.", log: log, type: .info)
                 self.currentShortcutLabel.stringValue = "Use Cmd/Ctrl/Opt + Key"
                 // Do not consume the event here; let the user try again or accept it.
                 // To strictly enforce, you could return nil here after setting the message.
                 // For now, we'll allow it to be saved if the user proceeds.
            } else if pressedModifiers.isEmpty && !event.isModifierOnly {
                // No modifiers pressed, just a plain key (e.g., 'A')
                os_log("Shortcut recording: Plain key pressed without typical modifiers (Cmd,Ctrl,Opt).", log: log, type: .info)
                // Allow plain keys, but be mindful they might conflict with typing.
            }


            let keyCode = Int(event.keyCode)
            let modifiers = pressedModifiers.rawValue // Store the raw UInt value

            os_log("Shortcut recorded - KeyCode: %d, Modifiers: %u. Saving.", log: log, type: .info, keyCode, modifiers)
            PreferencesManager.shared.shortcutKeyCode = keyCode
            PreferencesManager.shared.shortcutModifierFlags = modifiers
            
            self.stopRecordingShortcut(save: true) // Stop recording and save the new shortcut.
            return nil // Consume the event that set the shortcut.
        }
        os_log("Local event monitor for shortcut recording added.", log: log, type: .debug)
    }

    private func stopRecordingShortcut(save: Bool) {
        guard isRecordingShortcut else { return } // Only proceed if currently recording.
        
        os_log("Stopping shortcut recording. Save requested: %{public}@", log: log, type: .info, String(describing: save))
        isRecordingShortcut = false
        changeShortcutButton.title = "Change..." // Reset button title
        currentShortcutLabel.textColor = .secondaryLabelColor // Reset label color

        // Remove the event monitor.
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutMonitor = nil
            os_log("Shortcut event monitor removed.", log: log, type: .debug)
        }
        
        // Update the display to show the new (or old, if not saved) shortcut.
        updateShortcutDisplay()
        
        if save {
            os_log("Shortcut changes were saved (or attempted).", log: log, type: .debug)
        } else {
            os_log("Shortcut recording stopped without saving changes.", log: log, type: .debug)
        }
    }
}

// Helper extension for NSEvent from original code.
// This checks if an event is purely a modifier key press without other characters.
extension NSEvent {
    var isModifierOnly: Bool {
        // Check if the charactersIgnoringModifiers is empty (meaning no "typed" character)
        let chars = self.charactersIgnoringModifiers ?? ""
        // Check if the keyCode corresponds to a known modifier key.
        let knownModifierKeyCodes: [Int] = [
            kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
            kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
            kVK_Function // Fn key
        ].map { Int($0) } // Ensure they are Int for comparison with keyCode

        return knownModifierKeyCodes.contains(Int(self.keyCode)) && chars.isEmpty
    }
}
