import Cocoa
import os.log // Import for Unified Logging

// Define a log object for consistent logging within AppOverlayWindow
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.pogorielov.BetterTab", category: "AppOverlayWindow")

// --- Custom Window for the App Switcher ---
class AppOverlayWindow: NSPanel {

    // MARK: - Properties
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var visualEffectView: NSVisualEffectView!
    private var searchStringLabel: NSTextField!

    private var currentApps: [NSRunningApplication] = [] // Apps currently displayed
    private var currentSelectedIndex: Int = 0
    // currentTypedString is no longer stored here as it's passed directly to update
    // private var currentTypedString: String = ""

    // MARK: - Core Layout Constants
    struct CoreLayoutConstants {
        let iconSize: CGFloat
        let selectionInternalPadding: CGFloat
        let appNameFontSize: CGFloat
        let appNameHeight: CGFloat
        let spacingBetweenIconAndName: CGFloat

        let itemCellWidth: CGFloat
        let itemCellHeight: CGFloat
        
        let itemSpacing: CGFloat
        let horizontalWindowPadding: CGFloat
        let verticalWindowPadding: CGFloat
        let windowCornerRadius: CGFloat
        let highlightCornerRadius: CGFloat
        
        let minVisualItemCountForWidth: Int
        let maxVisibleItemsInOverlay: Int

        let searchStringHeight: CGFloat
        let searchStringFontSize: CGFloat
        let spacingBetweenItemsAndSearchLabel: CGFloat
        
        init(iconSize: CGFloat, selectionInternalPadding: CGFloat, appNameFontSize: CGFloat, spacingBetweenIconAndName: CGFloat,
             itemSpacing: CGFloat, horizontalWindowPadding: CGFloat, verticalWindowPadding: CGFloat,
             windowCornerRadius: CGFloat, highlightCornerRadius: CGFloat,
             minVisualItemCountForWidth: Int = 1,
             maxVisibleItemsInOverlay: Int = 9,
             searchStringHeight: CGFloat = 24,
             searchStringFontSize: CGFloat = 15,
             spacingBetweenItemsAndSearchLabel: CGFloat = 10) {
            self.iconSize = iconSize
            self.selectionInternalPadding = selectionInternalPadding
            self.appNameFontSize = appNameFontSize
            self.appNameHeight = appNameFontSize + 8
            self.spacingBetweenIconAndName = spacingBetweenIconAndName
            
            self.itemCellWidth = iconSize + (2 * selectionInternalPadding)
            self.itemCellHeight = (2 * selectionInternalPadding) + iconSize + spacingBetweenIconAndName + self.appNameHeight
            
            self.itemSpacing = itemSpacing
            self.horizontalWindowPadding = horizontalWindowPadding
            self.verticalWindowPadding = verticalWindowPadding
            self.windowCornerRadius = windowCornerRadius
            self.highlightCornerRadius = highlightCornerRadius
            self.minVisualItemCountForWidth = minVisualItemCountForWidth
            self.maxVisibleItemsInOverlay = maxVisibleItemsInOverlay

            self.searchStringHeight = searchStringHeight
            self.searchStringFontSize = searchStringFontSize
            self.spacingBetweenItemsAndSearchLabel = spacingBetweenItemsAndSearchLabel
        }
    }
    
    private static let nativeLookConstants = CoreLayoutConstants(
        iconSize: 72,
        selectionInternalPadding: 10,
        appNameFontSize: 13,
        spacingBetweenIconAndName: 4,
        itemSpacing: 8,
        horizontalWindowPadding: 15,
        verticalWindowPadding: 12,
        windowCornerRadius: 16,
        highlightCornerRadius: 9,
        minVisualItemCountForWidth: 1,
        maxVisibleItemsInOverlay: 7,
        searchStringHeight: 26,
        searchStringFontSize: 16,
        spacingBetweenItemsAndSearchLabel: 12
    )
    private let layout: CoreLayoutConstants = AppOverlayWindow.nativeLookConstants

    // MARK: - Initialization
    // Initializer now expects typedString
    init(apps: [NSRunningApplication], selectedIndex: Int, typedString: String) {
        self.currentApps = apps
        self.currentSelectedIndex = selectedIndex
        // self.currentTypedString = typedString // No longer storing it as a property if always passed in update
        let initialRect = NSRect(x: 0, y: 0, width: 100, height: 100)

        super.init(contentRect: initialRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        os_log("AppOverlayWindow init started.", log: log, type: .debug)

        self.isFloatingPanel = true
        self.level = .modalPanel
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.animationBehavior = .none

        setupVisualEffectView()
        setupSearchStringLabel()
        setupCollectionView()
        setupConstraints()

        update(apps: apps, selectedIndex: selectedIndex, typedString: typedString)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appearancePreferencesDidChange),
                                               name: .appearancePreferenceChanged, object: nil)
        os_log("AppOverlayWindow init finished.", log: log, type: .info)
    }
    
    deinit {
        os_log("Deinitializing AppOverlayWindow.", log: log, type: .info)
        NotificationCenter.default.removeObserver(self, name: .appearancePreferenceChanged, object: nil)
    }

    @objc private func appearancePreferencesDidChange() {
        os_log("Detected appearance preference change. Reloading collection view.", log: log, type: .debug)
        self.collectionView.reloadData()
        searchStringLabel.textColor = NSColor.secondaryLabelColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    static func getLayoutConstants() -> CoreLayoutConstants {
        return AppOverlayWindow.nativeLookConstants
    }

    // MARK: - Setup UI Elements
     private func setupVisualEffectView() {
         visualEffectView = NSVisualEffectView()
         visualEffectView.translatesAutoresizingMaskIntoConstraints = false
         visualEffectView.material = .hudWindow
         visualEffectView.blendingMode = .behindWindow
         visualEffectView.state = .active
         visualEffectView.wantsLayer = true
         visualEffectView.layer?.cornerRadius = layout.windowCornerRadius
         self.contentView?.addSubview(visualEffectView)
         os_log("VisualEffectView setup complete.", log: log, type: .debug)
     }

    private func setupSearchStringLabel() {
        searchStringLabel = NSTextField(labelWithString: "")
        searchStringLabel.translatesAutoresizingMaskIntoConstraints = false
        searchStringLabel.font = NSFont.systemFont(ofSize: layout.searchStringFontSize, weight: .medium)
        searchStringLabel.textColor = NSColor.secondaryLabelColor
        searchStringLabel.alignment = .center
        searchStringLabel.isBezeled = false
        searchStringLabel.isEditable = false
        searchStringLabel.drawsBackground = false
        searchStringLabel.lineBreakMode = .byTruncatingTail
        searchStringLabel.maximumNumberOfLines = 1
        searchStringLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        visualEffectView.addSubview(searchStringLabel)
        os_log("SearchStringLabel setup complete with truncation and low compression resistance.", log: log, type: .debug)
    }

    private func setupCollectionView() {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: layout.itemCellWidth, height: layout.itemCellHeight)
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = layout.itemSpacing
        flowLayout.minimumLineSpacing = layout.itemSpacing

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = flowLayout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.wantsLayer = true
        collectionView.register(AppItemView.self, forItemWithIdentifier: AppItemView.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsetsZero
        
        if #available(macOS 10.7, *) {
            scrollView.scrollerStyle = .overlay
        }
        
        visualEffectView.addSubview(scrollView)
        os_log("CollectionView and ScrollView setup complete. Horizontal scroller disabled.", log: log, type: .debug)
    }

     private func setupConstraints() {
         guard let contentView = contentView else {
             os_log("Content view is nil, cannot setup constraints.", log: log, type: .error)
             return
         }
         NSLayoutConstraint.activate([
             visualEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
             visualEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
             visualEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
             visualEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

             scrollView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: layout.verticalWindowPadding),
             scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: layout.horizontalWindowPadding),
             scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -layout.horizontalWindowPadding),
             scrollView.heightAnchor.constraint(equalToConstant: layout.itemCellHeight),

             searchStringLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: layout.spacingBetweenItemsAndSearchLabel),
             searchStringLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: layout.horizontalWindowPadding),
             searchStringLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -layout.horizontalWindowPadding),
             searchStringLabel.heightAnchor.constraint(equalToConstant: layout.searchStringHeight),
             searchStringLabel.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -layout.verticalWindowPadding)
         ])
         os_log("Constraints activated for VisualEffectView, ScrollView, and SearchStringLabel.", log: log, type: .debug)
     }

    // MARK: - Update Content & Resize
    // Update method also expects typedString
    func update(apps: [NSRunningApplication], selectedIndex: Int, typedString: String) {
        os_log("Updating overlay with %d apps, selected index: %d, typed string: '%{private}@'", log: log, type: .debug, apps.count, selectedIndex, typedString)
        self.currentApps = apps
        self.currentSelectedIndex = selectedIndex
        // self.currentTypedString = typedString // No longer storing if always passed

        let maxCharsToDisplay = 40
        let displaySearchString: String
        if typedString.isEmpty {
            displaySearchString = " "
        } else if typedString.count > maxCharsToDisplay {
            displaySearchString = "…" + String(typedString.suffix(maxCharsToDisplay - 1))
            os_log("Search string truncated for display. Full: '%{private}@', Displayed: '%{public}@'", log: log, type: .debug, typedString, displaySearchString)
        } else {
            displaySearchString = typedString
        }
        self.searchStringLabel.stringValue = displaySearchString
        
        self.visualEffectView.layer?.cornerRadius = layout.windowCornerRadius
        if let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
            flowLayout.itemSize = NSSize(width: layout.itemCellWidth, height: layout.itemCellHeight)
            flowLayout.minimumInteritemSpacing = layout.itemSpacing
        }

        calculateAndSetFrame()

        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.scrollToSelection()
            os_log("CollectionView reloaded and scrolled to selection.", log: log, type: .debug)
        }
    }

    private func calculateAndSetFrame() {
        let actualDisplayedItemCount = currentApps.count
        os_log("Calculating and setting window frame. Actual displayed item count: %d", log: log, type: .debug, actualDisplayedItemCount)
        
        let itemsToUseForWidthCalculation: Int
        if actualDisplayedItemCount == 0 {
            itemsToUseForWidthCalculation = layout.minVisualItemCountForWidth
        } else {
            itemsToUseForWidthCalculation = min(actualDisplayedItemCount, layout.maxVisibleItemsInOverlay)
        }
        let effectiveItemsForWidth = max(itemsToUseForWidthCalculation, layout.minVisualItemCountForWidth)

        let requiredHeight = layout.verticalWindowPadding +
                             layout.itemCellHeight +
                             layout.spacingBetweenItemsAndSearchLabel +
                             layout.searchStringHeight +
                             layout.verticalWindowPadding
        
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 10000
        
        let totalItemCellsWidth = CGFloat(effectiveItemsForWidth) * layout.itemCellWidth
        let totalSpacingBetweenItems = CGFloat(max(0, effectiveItemsForWidth - 1)) * layout.itemSpacing
        let requiredContentAreaWidth = totalItemCellsWidth + totalSpacingBetweenItems
        
        var desiredWindowWidth = requiredContentAreaWidth + (2 * layout.horizontalWindowPadding)
        
        let maxWidth = screenWidth - 40
        let finalWindowWidth = min(desiredWindowWidth, maxWidth)
        
        let newSize = NSSize(width: finalWindowWidth, height: requiredHeight)
        os_log("Calculated new window size: {width: %f, height: %f} based on effectiveItemsForWidth: %d", log: log, type: .debug, newSize.width, newSize.height, effectiveItemsForWidth)

        guard let screen = NSScreen.main else {
            os_log("Cannot calculate new origin: NSScreen.main is nil. Setting size only.", log: log, type: .error)
            if self.frame.size != newSize { self.setContentSize(newSize) }
            return
        }
        let screenFrame = screen.visibleFrame
        let newOriginX = screenFrame.origin.x + (screenFrame.width - newSize.width) / 2
        let verticalOffsetFactor: CGFloat = 0.15
        let newOriginY = screenFrame.origin.y + (screenFrame.height - newSize.height) / 2 + (screenFrame.height * verticalOffsetFactor)
        let newFrame = NSRect(origin: NSPoint(x: newOriginX, y: newOriginY), size: newSize)

        let currentFrame = self.frame
        let dx = abs(currentFrame.origin.x - newFrame.origin.x)
        let dy = abs(currentFrame.origin.y - newFrame.origin.y)
        let dw = abs(currentFrame.size.width - newFrame.size.width)
        let dh = abs(currentFrame.size.height - newFrame.size.height)
        let tolerance: CGFloat = 0.5

        if dx > tolerance || dy > tolerance || dw > tolerance || dh > tolerance {
            os_log("Setting new window frame: Origin={%{public}f, %{public}f}, Size={%{public}f, %{public}f}", log: log, type: .debug, newFrame.origin.x, newFrame.origin.y, newFrame.size.width, newFrame.size.height)
            self.setFrame(newFrame, display: true, animate: false)
        } else {
            os_log("Window frame is already correct or within tolerance. No change.", log: log, type: .debug)
        }
    }

    // MARK: - Positioning & Scrolling
    override func center() {
        os_log("Explicit center() called. Recalculating and setting frame.", log: log, type: .debug)
        calculateAndSetFrame()
    }

    private func scrollToSelection() {
        guard !currentApps.isEmpty else { return }
        let safeSelectedIndex = max(0, min(currentSelectedIndex, currentApps.count - 1))
        guard collectionView.numberOfItems(inSection: 0) > 0 else { return }
        guard safeSelectedIndex < collectionView.numberOfItems(inSection: 0) else { return }
        let indexPath = IndexPath(item: safeSelectedIndex, section: 0)
        DispatchQueue.main.async {
             guard self.collectionView.frame.width > 0, self.collectionView.frame.height > 0 else { return }
             os_log("Scrolling to item at indexPath: %@ (relative to displayed apps)", log: log, type: .debug, indexPath.description)
             self.collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredHorizontally)
             self.collectionView.deselectAll(nil)
             self.collectionView.selectItems(at: [indexPath], scrollPosition: [])
        }
    }
}

// MARK: - NSCollectionViewDataSource & Delegate
extension AppOverlayWindow: NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: NSCollectionView) -> Int { return 1 }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { return currentApps.count }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = collectionView.makeItem(withIdentifier: AppItemView.identifier, for: indexPath) as? AppItemView else { fatalError("Unable to dequeue AppItemView") }
        guard indexPath.item < currentApps.count else { return item }
        let app = currentApps[indexPath.item]
        item.configure(with: app, layoutConstants: self.layout)
        item.updateSelectionVisuals(isSelected: currentSelectedIndex == indexPath.item)
        return item
    }
    func collectionView(_ collectionView: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> { return [] }
    func collectionView(_ collectionView: NSCollectionView, shouldDeselectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> { return [] }
}
