import XCTest
@testable import BetterTab // This makes internal types/methods accessible if needed

class PreferencesManagerTests: XCTestCase {

    var preferencesManager: PreferencesManager!
    let userDefaultsSuiteName = "TestUserDefaults" // For isolated testing

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use a separate UserDefaults suite for testing to avoid interfering with actual app preferences
        UserDefaults().removePersistentDomain(forName: userDefaultsSuiteName)
        preferencesManager = PreferencesManager.shared // Assuming it uses UserDefaults.standard internally
                                                      // For more isolated tests, you might inject a UserDefaults instance.
                                                      // For simplicity here, we'll reset standard defaults.
        
        // Reset to default values before each test.
        // This assumes PreferencesManager modifies UserDefaults.standard.
        // A more robust approach for PreferencesManager would be to allow injecting a UserDefaults instance.
        let standardDefaults = UserDefaults.standard
        standardDefaults.removeObject(forKey: "fuzzySearchEnabled")
        standardDefaults.removeObject(forKey: "launchAtLoginEnabled")
        standardDefaults.removeObject(forKey: "shortcutKeyCode")
        standardDefaults.removeObject(forKey: "shortcutModifierFlags")
        standardDefaults.removeObject(forKey: "appBindings")
        standardDefaults.removeObject(forKey: "appTheme")
        standardDefaults.removeObject(forKey: "accentColorData")
        
        // Re-register defaults if your app does this upon initialization
        // preferencesManager.registerDefaultPreferences() // If you make this method public or testable
    }

    override func tearDownWithError() throws {
        preferencesManager = nil
        UserDefaults().removePersistentDomain(forName: userDefaultsSuiteName)
        try super.tearDownWithError()
    }

    func testDefaultFuzzySearchIsFalse() {
        XCTAssertFalse(preferencesManager.fuzzySearchEnabled, "Default fuzzy search should be false")
    }

    func testSetAndGetFuzzySearch() {
        preferencesManager.fuzzySearchEnabled = true
        XCTAssertTrue(preferencesManager.fuzzySearchEnabled, "Fuzzy search should be true after setting")

        preferencesManager.fuzzySearchEnabled = false
        XCTAssertFalse(preferencesManager.fuzzySearchEnabled, "Fuzzy search should be false after setting")
    }

    func testDefaultLaunchAtLoginIsFalse() {
        XCTAssertFalse(preferencesManager.launchAtLogin, "Default launch at login should be false")
    }

    func testSetAndGetLaunchAtLogin() {
        preferencesManager.launchAtLogin = true
        XCTAssertTrue(preferencesManager.launchAtLogin, "Launch at login should be true after setting")
    }

    func testDefaultThemeIsSystem() {
        // Assuming "system" is the default identifier you use
        XCTAssertEqual(preferencesManager.appTheme.lowercased(), "system", "Default theme should be 'system'")
    }

    func testSetAndGetTheme() {
        preferencesManager.appTheme = "dark"
        XCTAssertEqual(preferencesManager.appTheme, "dark", "Theme should be 'dark' after setting")
    }
    
    func testDefaultShortcutKeyCode() {
        // Assuming kVK_Tab is the default. You might need to import Carbon.HIToolbox
        // or define the constant if it's not available directly.
        // For example, if kVK_Tab is 0x30 (48 decimal)
        let defaultTabKeyCode = 48 // Or the actual value of kVK_Tab
        XCTAssertEqual(preferencesManager.shortcutKeyCode, defaultTabKeyCode, "Default shortcut key code should be Tab")
    }

    func testSetAndGetShortcut() {
        let newKeyCode = 50 // Example key code
        let newModifiers: UInt = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue

        preferencesManager.shortcutKeyCode = newKeyCode
        preferencesManager.shortcutModifierFlags = newModifiers

        XCTAssertEqual(preferencesManager.shortcutKeyCode, newKeyCode)
        XCTAssertEqual(preferencesManager.shortcutModifierFlags, newModifiers)
    }
    
    func testAppBindingCodable() throws {
        let binding = AppBinding(appBundleIdentifier: "com.example.app",
                                 appName: "ExampleApp",
                                 keyCode: 50,
                                 modifierFlags: NSEvent.ModifierFlags.option.rawValue)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode([binding]) // Encode as an array as per your manager
        
        let decoder = JSONDecoder()
        let decodedBindings = try decoder.decode([AppBinding].self, from: data)
        
        XCTAssertEqual(decodedBindings.count, 1)
        XCTAssertEqual(decodedBindings.first?.appBundleIdentifier, "com.example.app")
        XCTAssertEqual(decodedBindings.first?.appName, "ExampleApp")
        XCTAssertEqual(decodedBindings.first?.keyCode, 50)
    }

    func testAddAndRemoveAppBinding() {
        let initialCount = preferencesManager.appBindings.count
        let newBinding = AppBinding(appBundleIdentifier: "com.test.app", appName: "TestApp", keyCode: 10, modifierFlags: 10)
        
        preferencesManager.addAppBinding(newBinding)
        XCTAssertEqual(preferencesManager.appBindings.count, initialCount + 1, "Binding should be added")
        XCTAssertTrue(preferencesManager.appBindings.contains(where: { $0.id == newBinding.id }), "New binding should exist by ID")

        preferencesManager.removeAppBinding(id: newBinding.id)
        XCTAssertEqual(preferencesManager.appBindings.count, initialCount, "Binding should be removed")
        XCTAssertFalse(preferencesManager.appBindings.contains(where: { $0.id == newBinding.id }), "Removed binding should not exist by ID")
    }
    
    func testGetShortcutDisplayString() {
        // You would need to make stringFromKeyCode public or testable, or test via AppBinding
        let binding = AppBinding(appBundleIdentifier: "com.example.test",
                                 appName: "TestApp",
                                 keyCode: kVK_ANSI_A, // kVK_ANSI_A is 0
                                 modifierFlags: NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        // Expected string: "⇧⌘A"
        // This depends on your stringFromKeyCode implementation
        XCTAssertEqual(binding.getShortcutDisplayString(), "⇧⌘A", "Shortcut display string is incorrect")
    }
}

// You might need to make kVK_ANSI_A and other Carbon constants available or use their raw values.
// For example:
private let kVK_ANSI_A: Int = 0x00
// ... and so on for other keys you might test.
