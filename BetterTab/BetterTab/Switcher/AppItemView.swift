import Cocoa
import os.log // Import for Unified Logging

// Define a log object for consistent logging within AppItemView
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.pogorielov.BetterTab", category: "AppItemView")

class AppItemView: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("AppItemView")

    // MARK: - UI Elements

    private let iconImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        return imageView
    }()

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "App Name")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = NSColor.white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.isHidden = true // Name label is hidden by default, shown when selected
        return label
    }()

    private let selectionBackgroundView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.isHidden = true // Selection highlight is hidden by default
        return view
    }()

    // MARK: - Constraints
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var nameLabelTopConstraint: NSLayoutConstraint?
    private var nameLabelHeightConstraint: NSLayoutConstraint?
    private var iconTopInHighlightConstraint: NSLayoutConstraint?
    private var iconCenterXInHighlightConstraint: NSLayoutConstraint?


    // MARK: - Lifecycle

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        os_log("View loaded for AppItemView.", log: log, type: .debug)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("AppItemView viewDidLoad.", log: log, type: .debug)

        // Corrected Subview Order:
        // 1. selectionBackgroundView (bottom-most of these three)
        // 2. iconImageView (on top of selectionBackgroundView)
        // 3. nameLabel (on top of iconImageView, or positioned relative to it)

        // Remove existing subviews if they were added in a different order previously (defensive)
        iconImageView.removeFromSuperview()
        selectionBackgroundView.removeFromSuperview()
        nameLabel.removeFromSuperview()

        // Add subviews in the correct visual stacking order
        view.addSubview(selectionBackgroundView) // Add background first
        view.addSubview(iconImageView)           // Then icon
        view.addSubview(nameLabel)               // Then name label

        let layout = AppOverlayWindow.getLayoutConstants()

        // selectionBackgroundView constraints (fills the entire item view)
        NSLayoutConstraint.activate([
            selectionBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            selectionBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            selectionBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            selectionBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // iconImageView constraints (centered within the item view, with padding for name label)
        iconWidthConstraint = iconImageView.widthAnchor.constraint(equalToConstant: layout.iconSize)
        iconHeightConstraint = iconImageView.heightAnchor.constraint(equalToConstant: layout.iconSize)
        iconCenterXInHighlightConstraint = iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        // Position icon from the top, leaving space for its own content and the name label below
        iconTopInHighlightConstraint = iconImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: layout.selectionInternalPadding)
        
        // nameLabel constraints (below the icon, centered horizontally)
        nameLabelTopConstraint = nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: layout.spacingBetweenIconAndName)
        nameLabelHeightConstraint = nameLabel.heightAnchor.constraint(equalToConstant: layout.appNameHeight)

        NSLayoutConstraint.activate([
            iconWidthConstraint!,
            iconHeightConstraint!,
            iconCenterXInHighlightConstraint!,
            iconTopInHighlightConstraint!,

            nameLabelTopConstraint!,
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: layout.selectionInternalPadding / 2),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -layout.selectionInternalPadding / 2),
            nameLabelHeightConstraint!
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(appearancePreferencesDidChange),
                                               name: .appearancePreferenceChanged, object: nil)
        
        applyCurrentAppearancePreferences()
        os_log("AppItemView UI and constraints set up with corrected subview order.", log: log, type: .debug)
    }
    
    deinit {
        os_log("Deinitializing AppItemView for item: %{public}@", log: log, type: .debug, nameLabel.stringValue)
        NotificationCenter.default.removeObserver(self, name: .appearancePreferenceChanged, object: nil)
    }

    // MARK: - Configuration and Updates

    func configure(with app: NSRunningApplication, layoutConstants: AppOverlayWindow.CoreLayoutConstants) {
        os_log("Configuring AppItemView for app: %{public}@", log: log, type: .debug, app.localizedName ?? "Unknown")
        iconImageView.image = app.icon
        nameLabel.stringValue = app.localizedName ?? "Unknown App"
        
        iconWidthConstraint?.constant = layoutConstants.iconSize
        iconHeightConstraint?.constant = layoutConstants.iconSize
        
        nameLabel.font = NSFont.systemFont(ofSize: layoutConstants.appNameFontSize)
        nameLabelHeightConstraint?.constant = layoutConstants.appNameHeight
        
        selectionBackgroundView.layer?.cornerRadius = layoutConstants.highlightCornerRadius
        
        iconTopInHighlightConstraint?.constant = layoutConstants.selectionInternalPadding
        nameLabelTopConstraint?.constant = layoutConstants.spacingBetweenIconAndName
        
        updateSelectionVisuals(isSelected: self.isSelected)
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionVisuals(isSelected: isSelected)
        }
    }

    func updateSelectionVisuals(isSelected: Bool) {
        let layout = AppOverlayWindow.getLayoutConstants()
        let fontSize = layout.appNameFontSize

        iconImageView.isHidden = false // Icon is always visible

        if isSelected {
            selectionBackgroundView.isHidden = false
            selectionBackgroundView.layer?.backgroundColor = PreferencesManager.shared.accentColor.cgColor
            
            nameLabel.isHidden = false
            nameLabel.textColor = NSColor.white
            nameLabel.font = NSFont.boldSystemFont(ofSize: fontSize)
        } else {
            selectionBackgroundView.isHidden = true // Hide highlight when not selected
            selectionBackgroundView.layer?.backgroundColor = NSColor.clear.cgColor // Clear background
            
            nameLabel.isHidden = true // Name label hidden when not selected
            nameLabel.textColor = NSColor.white // Reset
            nameLabel.font = NSFont.systemFont(ofSize: fontSize)
        }
    }
    
    @objc private func appearancePreferencesDidChange() {
        os_log("Appearance preferences changed notification received in AppItemView for: %{public}@", log: log, type: .debug, nameLabel.stringValue)
        applyCurrentAppearancePreferences()
    }

    private func applyCurrentAppearancePreferences() {
        let layout = AppOverlayWindow.getLayoutConstants()
        let fontSize = layout.appNameFontSize

        if isSelected {
            selectionBackgroundView.layer?.backgroundColor = PreferencesManager.shared.accentColor.cgColor
            nameLabel.font = NSFont.boldSystemFont(ofSize: fontSize)
        } else {
            // Ensure font is reset if not selected, even if nameLabel is hidden
            nameLabel.font = NSFont.systemFont(ofSize: fontSize)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        os_log("Preparing AppItemView for reuse: %{public}@", log: log, type: .debug, nameLabel.stringValue)
        iconImageView.image = nil
        nameLabel.stringValue = ""
        isSelected = false // This will trigger updateSelectionVisuals to reset the state
    }
}
