import Cocoa
import Carbon.HIToolbox // For key constants
import UniformTypeIdentifiers // <-- Import for UTType

// --- Manages the UI Controls within the "Binds" Preferences Tab ---
class BindsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Data
    private var appBindings: [AppBinding] = []
    private var selectedBindingID: UUID?

    // MARK: - UI Elements
    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder // Standard border for tables
        return scrollView
    }()

    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil // No table header needed for this simple list
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.selectionHighlightStyle = .regular
        tableView.rowSizeStyle = .medium // Or .default

        // Define columns
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppColumn"))
        appColumn.title = "Application" // Not visible due to headerView = nil
        // Let the table view manage column width or set a flexible width
        // appColumn.width = 200

        let shortcutColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ShortcutColumn"))
        shortcutColumn.title = "Shortcut" // Not visible
        // shortcutColumn.width = 150

        tableView.addTableColumn(appColumn)
        tableView.addTableColumn(shortcutColumn)

        return tableView
    }()

    private lazy var addRemoveSegmentedControl: NSSegmentedControl = {
        // Use system symbols for + and -
        let images = [
            NSImage(systemSymbolName: "plus", accessibilityDescription: "Add binding")!,
            NSImage(systemSymbolName: "minus", accessibilityDescription: "Remove binding")!
        ]
        let control = NSSegmentedControl(images: images, trackingMode: .momentary, target: self, action: #selector(addRemoveSegmentClicked(_:)))
        control.translatesAutoresizingMaskIntoConstraints = false
        control.segmentStyle = .smallSquare
        // Disable minus by default until a row is selected
        control.setEnabled(false, forSegment: 1)
        return control
    }()

    private lazy var recordShortcutButton: NSButton = {
        let button = NSButton(title: "Set Shortcut", target: self, action: #selector(recordBindingShortcutClicked(_:)))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false // Disabled until a row is selected
        button.toolTip = "Set or change the shortcut for the selected app binding"
        return button
    }()
    
    private var isRecordingAppBindingShortcut = false
    private var appBindingShortcutMonitor: Any?


    // MARK: - View Lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 320)) // Adjusted size
        print("BindsViewController: View Loaded.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("BindsViewController: View Did Load.")
        setupUI()
        loadBindings()
        // Register for app binding changes
        NotificationCenter.default.addObserver(self, selector: #selector(appBindingsDidChange), name: .appBindingsChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .appBindingsChanged, object: nil)
        stopRecordingAppBindingShortcut(save: false, forBindingID: nil) // Clean up monitor
        print("BindsViewController: Deinitialized.")
    }

    // MARK: - Notification Handling
    @objc private func appBindingsDidChange() {
        print("BindsViewController: Detected app bindings change from PreferencesManager.")
        loadBindings() // Reload and refresh table
    }

    // MARK: - UI Setup

    private func setupUI() {
        scrollView.documentView = tableView
        view.addSubview(scrollView)
        view.addSubview(addRemoveSegmentedControl)
        view.addSubview(recordShortcutButton)

        NSLayoutConstraint.activate([
            // ScrollView (containing TableView)
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: addRemoveSegmentedControl.topAnchor, constant: -10),

            // Add/Remove Segmented Control
            addRemoveSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addRemoveSegmentedControl.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            addRemoveSegmentedControl.widthAnchor.constraint(equalToConstant: 70), // Adjust width as needed

            // Record Shortcut Button
            recordShortcutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            recordShortcutButton.centerYAnchor.constraint(equalTo: addRemoveSegmentedControl.centerYAnchor)
        ])
        print("BindsViewController: UI Setup Complete.")
    }

    // MARK: - Data Handling

    private func loadBindings() {
        appBindings = PreferencesManager.shared.appBindings
        // Optional: Sort bindings by app name for display consistency
        appBindings.sort { ($0.appName).localizedStandardCompare($1.appName) == .orderedAscending }
        tableView.reloadData()
        updateButtonStates() // Update based on selection after reload
        print("BindsViewController: Loaded and displayed \(appBindings.count) app bindings.")
    }

    private func updateButtonStates() {
        let selectedRow = tableView.selectedRow
        addRemoveSegmentedControl.setEnabled(selectedRow != -1, forSegment: 1) // Enable '-' if a row is selected
        recordShortcutButton.isEnabled = (selectedRow != -1)
    }

    // MARK: - Actions

    @objc private func addRemoveSegmentClicked(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 { // "+" segment
            addBindingClicked()
        } else if sender.selectedSegment == 1 { // "-" segment
            removeBindingClicked()
        }
    }

    private func addBindingClicked() {
        print("Add Binding (+) button clicked.")
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose an Application"
        // openPanel.showsResizeIndicator = true // DEPRECATED
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = false
        // --- Use allowedContentTypes instead of allowedFileTypes ---
        if #available(macOS 11.0, *) { // UTType is available macOS 11+
            openPanel.allowedContentTypes = [UTType.applicationBundle]
        } else {
            // Fallback for older macOS if necessary, though .app should work
            openPanel.allowedFileTypes = ["app"]
        }
        openPanel.allowsMultipleSelection = false

        openPanel.begin { [weak self] (result) -> Void in
            guard let self = self else { return }
            if result == .OK {
                if let appURL = openPanel.url {
                    let appBundle = Bundle(url: appURL)
                    guard let bundleId = appBundle?.bundleIdentifier,
                          let appName = appBundle?.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String else {
                        print("Error: Could not get bundle ID or name for selected app.")
                        let alert = NSAlert()
                        alert.messageText = "Invalid Application"
                        alert.informativeText = "Could not retrieve necessary information from the selected application."
                        alert.alertStyle = .warning
                        alert.runModal()
                        return
                    }

                    if self.appBindings.contains(where: { $0.appBundleIdentifier == bundleId }) {
                         print("Warning: App binding for \(appName) already exists.")
                         let alert = NSAlert()
                         alert.messageText = "Duplicate Binding"
                         alert.informativeText = "A binding for '\(appName)' already exists. You can edit the existing one."
                         alert.alertStyle = .informational
                         alert.runModal()
                         return
                    }

                    let newBinding = AppBinding(appBundleIdentifier: bundleId,
                                                appName: appName,
                                                keyCode: -1, // Indicate no shortcut set
                                                modifierFlags: 0)
                    PreferencesManager.shared.addAppBinding(newBinding)
                    // loadBindings() will be called by the notification observer
                }
            }
        }
    }

    private func removeBindingClicked() {
        print("Remove Binding (-) button clicked.")
        let selectedRow = tableView.selectedRow
        guard selectedRow != -1, selectedRow < appBindings.count else {
            print("No binding selected or selection out of bounds.")
            return
        }

        let bindingToRemove = appBindings[selectedRow]
        PreferencesManager.shared.removeAppBinding(id: bindingToRemove.id)
        // loadBindings() will be called by the notification observer
        tableView.deselectRow(selectedRow)
        updateButtonStates()
    }

    @objc private func recordBindingShortcutClicked(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        guard selectedRow != -1, selectedRow < appBindings.count else {
            print("Record shortcut: No binding selected.")
            return
        }
        let bindingToEdit = appBindings[selectedRow]
        print("Record shortcut for: \(bindingToEdit.appName)")

        if isRecordingAppBindingShortcut {
            stopRecordingAppBindingShortcut(save: false, forBindingID: selectedBindingID)
        } else {
            startRecordingAppBindingShortcut(forBindingID: bindingToEdit.id)
        }
    }
    
    // MARK: - App Binding Shortcut Recording

    private func startRecordingAppBindingShortcut(forBindingID bindingID: UUID) {
        guard let bindingIndex = appBindings.firstIndex(where: { $0.id == bindingID }) else { return }
        
        print("Starting shortcut recording for app binding: \(appBindings[bindingIndex].appName)")
        isRecordingAppBindingShortcut = true
        selectedBindingID = bindingID
        
        recordShortcutButton.title = "Stop Recording"
        
        view.window?.makeFirstResponder(view)

        appBindingShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self, self.isRecordingAppBindingShortcut, self.selectedBindingID == bindingID else {
                return event
            }

            if event.isModifierOnly { return event }

            let requiredModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            let pressedModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if pressedModifiers.intersection(requiredModifiers).isEmpty && !pressedModifiers.isEmpty {
                 print("Shortcut Recording (App Binding): Shortcut should ideally include Cmd, Ctrl, or Opt, or be a plain key.")
                 if pressedModifiers.isEmpty || pressedModifiers == .shift {
                     return nil
                 }
            }

            let keyCode = Int(event.keyCode)
            let modifiers = pressedModifiers.rawValue

            if var bindingToUpdate = self.appBindings.first(where: { $0.id == bindingID }) {
                bindingToUpdate.keyCode = keyCode
                bindingToUpdate.modifierFlags = modifiers
                PreferencesManager.shared.updateAppBinding(bindingToUpdate)
            }
            
            self.stopRecordingAppBindingShortcut(save: true, forBindingID: bindingID)
            return nil
        }
    }

    private func stopRecordingAppBindingShortcut(save: Bool, forBindingID bindingID: UUID?) {
        guard isRecordingAppBindingShortcut else { return }
        if let id = bindingID, id != selectedBindingID { return }

        print("Stopping shortcut recording for app binding. Save: \(save)")
        isRecordingAppBindingShortcut = false
        selectedBindingID = nil
        recordShortcutButton.title = "Set Shortcut"

        if let monitor = appBindingShortcutMonitor {
            NSEvent.removeMonitor(monitor)
            appBindingShortcutMonitor = nil
            print("App binding shortcut monitor removed.")
        }
        loadBindings()
    }


    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return appBindings.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < appBindings.count else { return nil }
        let binding = appBindings[row]

        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("AppColumn") {
            let cellIdentifier = NSUserInterfaceItemIdentifier("AppCell")
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

            if cellView == nil {
                cellView = NSTableCellView(frame: .zero)
                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.imageScaling = .scaleProportionallyUpOrDown

                cellView!.addSubview(imageView)
                cellView!.addSubview(textField)
                
                cellView!.imageView = imageView
                cellView!.textField = textField

                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 2),
                    imageView.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 18),
                    imageView.heightAnchor.constraint(equalToConstant: 18),

                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 5),
                    textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -2),
                    textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
                ])
            }
            
            cellView?.textField?.stringValue = binding.appName
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: binding.appBundleIdentifier) {
                // Attempt to get icon from standard location first
                let iconPath = appURL.appendingPathComponent("Contents/Resources/AppIcon.icns").path
                var appIcon = NSImage(contentsOfFile: iconPath)
                if appIcon == nil { // Fallback to workspace icon
                    appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                }
                cellView?.imageView?.image = appIcon
            } else {
                cellView?.imageView?.image = NSImage(systemSymbolName: "questionmark.app", accessibilityDescription: "Unknown app")
            }
            return cellView

        } else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("ShortcutColumn") {
            let cellIdentifier = NSUserInterfaceItemIdentifier("ShortcutCell")
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

            if cellView == nil {
                cellView = NSTableCellView(frame: .zero)
                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.alignment = .center
                textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                cellView!.addSubview(textField)
                cellView!.textField = textField
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 2),
                    textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -2),
                    textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
                ])
            }
            cellView?.textField?.stringValue = binding.keyCode == -1 ? "Not Set" : binding.getShortcutDisplayString()
            return cellView
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
        if isRecordingAppBindingShortcut {
            stopRecordingAppBindingShortcut(save: false, forBindingID: selectedBindingID)
        }
    }
}
