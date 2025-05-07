import Cocoa
import os.log // Import for Unified Logging

// Define a log object for consistent logging
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.pogorielov.BetterTab", category: "AppearancePreferencesViewController")

// --- Manages the UI Controls within the "Appearance" Preferences Tab ---
class AppearancePreferencesViewController: NSViewController {

    // MARK: - UI Elements

    private lazy var themeLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Theme:")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var themePopUpButton: NSPopUpButton = {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        popUp.translatesAutoresizingMaskIntoConstraints = false
        popUp.addItems(withTitles: ["System", "Light", "Dark"]) // Standard theme options
        popUp.target = self
        popUp.action = #selector(themeChanged(_:))
        return popUp
    }()

    private lazy var accentColorLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Selection Accent:")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var accentColorWell: NSColorWell = {
        let colorWell = NSColorWell()
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.target = self
        colorWell.action = #selector(accentColorChanged(_:))
        // colorWell.supportsAlpha = false // Typically, accent colors don't need alpha
        return colorWell
    }()
    
    // Overlay Size UI Elements were removed in the user-provided code.

    // Main stack view for layout
    private lazy var stackView: NSStackView = {
        let views: [NSView] = [
            createThemeRow(),       // Helper method for theme UI
            createAccentColorRow()  // Helper method for accent color UI
        ]
        let stack = NSStackView(views: views)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading // Align content to the leading edge
        stack.spacing = 15         // Spacing between preference items
        return stack
    }()

    // MARK: - View Lifecycle

    override func loadView() {
        // Frame height adjusted as one row (Overlay Size) was removed in the original code.
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 120)) // Adjusted height
        os_log("View Loaded.", log: log, type: .debug)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("View Did Load.", log: log, type: .debug)
        setupUI()
        loadPreferences()
        // Observe changes to appearance preferences (e.g., if changed by another part of the app or system)
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesDidChange),
                                               name: .appearancePreferenceChanged, object: nil)
    }
    
    deinit {
        os_log("Deinitializing AppearancePreferencesViewController.", log: log, type: .debug)
        NotificationCenter.default.removeObserver(self, name: .appearancePreferenceChanged, object: nil)
    }

    // Called when appearance preferences (theme, accent color) change.
    @objc private func preferencesDidChange() {
        os_log("Appearance preferences changed notification received. Reloading UI.", log: log, type: .debug)
        // Ensure UI updates are on the main thread, though loadPreferences should handle this if it modifies UI.
        DispatchQueue.main.async {
            self.loadPreferences()
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            // Allow stack view to determine its own bottom based on content.
            // stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
        os_log("UI Setup Complete.", log: log, type: .debug)
    }
    
    // Helper to create the theme selection row.
    private func createThemeRow() -> NSView {
        let themeStack = NSStackView(views: [themeLabel, themePopUpButton])
        themeStack.orientation = .horizontal
        themeStack.spacing = 8 // Standard spacing
        // Ensure the label doesn't stretch unnecessarily.
        themeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        // Allow popUpButton to take available space or have a defined width.
        // themePopUpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        return themeStack
    }

    // Helper to create the accent color selection row.
    private func createAccentColorRow() -> NSView {
        let accentStack = NSStackView(views: [accentColorLabel, accentColorWell])
        accentStack.orientation = .horizontal
        accentStack.spacing = 8
        accentColorLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        // Give the color well a specific, reasonable width.
        accentColorWell.widthAnchor.constraint(equalToConstant: 60).isActive = true
        return accentStack
    }
    
    // createOverlaySizeRow() was removed in the user-provided code.

    // MARK: - Load and Save Preferences

    private func loadPreferences() {
        os_log("Loading appearance preferences into UI.", log: log, type: .debug)
        
        // Load and set the current theme in the pop-up button.
        let currentTheme = PreferencesManager.shared.appTheme.lowercased()
        var themeIndex = 0 // Default to "System"
        if currentTheme == "light" {
            themeIndex = 1
        } else if currentTheme == "dark" {
            themeIndex = 2
        }
        themePopUpButton.selectItem(at: themeIndex)
        os_log("Theme loaded: %{public}@", log: log, type: .debug, currentTheme)
        
        // Load and set the current accent color in the color well.
        accentColorWell.color = PreferencesManager.shared.accentColor
        os_log("Accent color loaded.", log: log, type: .debug) // Avoid logging color directly unless for verbose debugging
        
        // Overlay size loading was removed in the user-provided code.
    }

    // MARK: - Action Methods
    
    @objc private func themeChanged(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.selectedItem?.title else {
            os_log("Theme changed, but selected item title is nil. No action taken.", log: log, type: .default)
            return
        }
        let newTheme = selectedTitle.lowercased()
        PreferencesManager.shared.appTheme = newTheme
        os_log("Theme changed by user to: %{public}@", log: log, type: .info, newTheme)
        // PreferencesManager's setter for appTheme will post .appearancePreferenceChanged notification
        // and call applyThemePreference.
    }
    
    @objc private func accentColorChanged(_ sender: NSColorWell) {
        let newColor = sender.color
        PreferencesManager.shared.accentColor = newColor
        os_log("Accent Color changed by user.", log: log, type: .info) // Avoid logging color directly
        // PreferencesManager's setter for accentColor will post .appearancePreferenceChanged notification.
    }
    
    // overlaySizeChanged action was removed in the user-provided code.
}
