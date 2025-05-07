import Foundation
import Cocoa
import Carbon.HIToolbox // For key constants like kVK_Tab
import os.log // Import for Unified Logging

// Define a log object for consistent logging within PreferencesManager
private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.pogorielov.BetterTab", category: "PreferencesManager")

// --- Structure to hold App Binding Info ---
struct AppBinding: Codable, Identifiable, Hashable {
    var id = UUID()
    var appBundleIdentifier: String
    var appName: String
    var keyCode: Int
    var modifierFlags: UInt

    func getShortcutDisplayString() -> String {
        return PreferencesManager.shared.stringFromKeyCode(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifierFlags))
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AppBinding, rhs: AppBinding) -> Bool { lhs.id == rhs.id }
}

class PreferencesManager {
    static let shared = PreferencesManager()

    private enum PrefKeys {
        static let fuzzySearch = "fuzzySearchEnabled"
        static let launchAtLogin = "launchAtLoginEnabled"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifierFlags = "shortcutModifierFlags"
        static let appBindings = "appBindings"
        static let theme = "appTheme"
        static let accentColorData = "accentColorData"
    }

    private let defaultKeyCode = kVK_Tab
    private let defaultModifierFlags: UInt = NSEvent.ModifierFlags.option.rawValue
    private var defaultAccentColor: NSColor {
        if #available(macOS 10.14, *) { return NSColor.controlAccentColor }
        else { return NSColor.systemBlue }
    }
    private let defaultTheme = "system"


    private init() {
        registerDefaultPreferences()
        os_log("PreferencesManager Initialized. Defaults registered.", log: log, type: .info)
    }

    private func registerDefaultPreferences() {
        let defaultBindingsData: Data
        do {
            defaultBindingsData = try JSONEncoder().encode([AppBinding]())
        } catch {
            os_log("Failed to encode default empty app bindings: %{public}@", log: log, type: .error, error.localizedDescription)
            defaultBindingsData = Data() // Fallback to empty data
        }

        let defaultAccentColorData: Data
        do {
            defaultAccentColorData = try NSKeyedArchiver.archivedData(withRootObject: defaultAccentColor, requiringSecureCoding: false)
        } catch {
            os_log("Failed to archive default accent color: %{public}@", log: log, type: .error, error.localizedDescription)
            defaultAccentColorData = Data() // Fallback to empty data
        }
        
        let defaults: [String: Any] = [
            PrefKeys.fuzzySearch: false,
            PrefKeys.launchAtLogin: false,
            PrefKeys.shortcutKeyCode: defaultKeyCode,
            PrefKeys.shortcutModifierFlags: defaultModifierFlags,
            PrefKeys.appBindings: defaultBindingsData,
            PrefKeys.theme: defaultTheme, // Original code had "system"
            PrefKeys.accentColorData: defaultAccentColorData
        ]
        UserDefaults.standard.register(defaults: defaults)
        os_log("Registered default preferences.", log: log, type: .debug)
    }

    var fuzzySearchEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: PrefKeys.fuzzySearch) }
        set {
            UserDefaults.standard.set(newValue, forKey: PrefKeys.fuzzySearch)
            os_log("Fuzzy Search preference changed to: %{public}@", log: log, type: .debug, String(describing: newValue))
        }
    }

    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: PrefKeys.launchAtLogin) }
        set {
            UserDefaults.standard.set(newValue, forKey: PrefKeys.launchAtLogin)
            os_log("Launch at Login preference changed to: %{public}@", log: log, type: .debug, String(describing: newValue))
            (NSApp.delegate as? AppDelegate)?.updateLoginItemStatus()
        }
    }

    var appTheme: String {
        get { UserDefaults.standard.string(forKey: PrefKeys.theme) ?? defaultTheme }
        set {
            UserDefaults.standard.set(newValue, forKey: PrefKeys.theme)
            os_log("App Theme preference changed to: %{public}@", log: log, type: .debug, newValue)
            applyThemePreference()
            NotificationCenter.default.post(name: .appearancePreferenceChanged, object: nil)
        }
    }

    var accentColor: NSColor {
        get {
            guard let colorData = UserDefaults.standard.data(forKey: PrefKeys.accentColorData) else {
                 os_log("No accent color data found, returning default.", log: log, type: .debug)
                return defaultAccentColor
            }
            do {
                if let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
                    return color
                } else {
                    os_log("Failed to unarchive NSColor, data might be corrupted or wrong type. Returning default.", log: log, type: .default)
                }
            } catch {
                os_log("Error unarchiving accent color: %{public}@. Returning default.", log: log, type: .error, error.localizedDescription)
            }
            return defaultAccentColor
        }
        set {
            do {
                let colorData = try NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
                UserDefaults.standard.set(colorData, forKey: PrefKeys.accentColorData)
                os_log("Accent Color preference changed.", log: log, type: .debug)
                NotificationCenter.default.post(name: .appearancePreferenceChanged, object: nil)
            } catch {
                os_log("Error archiving accent color: %{public}@", log: log, type: .error, error.localizedDescription)
            }
        }
    }

    var shortcutKeyCode: Int {
        get { UserDefaults.standard.integer(forKey: PrefKeys.shortcutKeyCode) }
        set {
            UserDefaults.standard.set(newValue, forKey: PrefKeys.shortcutKeyCode)
            os_log("Shortcut Key Code preference changed to: %d", log: log, type: .debug, newValue)
            NotificationCenter.default.post(name: .shortcutPreferenceChanged, object: nil)
        }
    }

    var shortcutModifierFlags: UInt {
        get { UInt(UserDefaults.standard.integer(forKey: PrefKeys.shortcutModifierFlags)) }
        set {
            UserDefaults.standard.set(Int(newValue), forKey: PrefKeys.shortcutModifierFlags)
            os_log("Shortcut Modifier Flags preference changed to: %u", log: log, type: .debug, newValue)
            NotificationCenter.default.post(name: .shortcutPreferenceChanged, object: nil)
        }
    }

    var shortcutModifiers: NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: shortcutModifierFlags)
    }

    func getShortcutDisplayString() -> String {
        return stringFromKeyCode(keyCode: shortcutKeyCode, modifiers: shortcutModifiers)
    }

    var appBindings: [AppBinding] {
        get {
            guard let data = UserDefaults.standard.data(forKey: PrefKeys.appBindings) else {
                os_log("No app bindings data found, returning empty array.", log: log, type: .debug)
                return []
            }
            do {
                return try JSONDecoder().decode([AppBinding].self, from: data)
            } catch {
                 os_log("Error decoding app bindings: %{public}@. Returning empty array.", log: log, type: .error, error.localizedDescription)
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: PrefKeys.appBindings)
                os_log("App Bindings updated. Count: %d", log: log, type: .debug, newValue.count)
                NotificationCenter.default.post(name: .appBindingsChanged, object: nil)
            } catch {
                os_log("Error encoding app bindings: %{public}@", log: log, type: .error, error.localizedDescription)
            }
        }
    }

    func addAppBinding(_ binding: AppBinding) {
        // Logic from original user-provided file
        var currentBindings = appBindings
        currentBindings.append(binding)
        appBindings = currentBindings // This will trigger the setter
        os_log("Added app binding for: %{public}@", log: log, type: .info, binding.appName)
    }

    func removeAppBinding(id: UUID) {
        // Logic from original user-provided file
        var currentBindings = appBindings
        let initialCount = currentBindings.count
        currentBindings.removeAll { $0.id == id }
        if currentBindings.count < initialCount {
             os_log("Removed app binding with ID: %{public}@", log: log, type: .info, id.uuidString)
        } else {
            os_log("Attempted to remove non-existent app binding with ID: %{public}@", log: log, type: .default, id.uuidString)
        }
        appBindings = currentBindings // This will trigger the setter
    }

    func updateAppBinding(_ updatedBinding: AppBinding) {
        // Logic from original user-provided file
        var currentBindings = appBindings
        if let index = currentBindings.firstIndex(where: { $0.id == updatedBinding.id }) {
            currentBindings[index] = updatedBinding
            appBindings = currentBindings // This will trigger the setter
            os_log("Updated app binding for: %{public}@", log: log, type: .info, updatedBinding.appName)
        } else {
            os_log("Attempted to update non-existent app binding with ID: %{public}@", log: log, type: .default, updatedBinding.id.uuidString)
        }
     }

    func applyThemePreference() {
        let theme = appTheme
        DispatchQueue.main.async {
             if #available(macOS 10.14, *) {
                 switch theme.lowercased() {
                 case "light":
                    NSApp.appearance = NSAppearance(named: .aqua)
                    os_log("Applied Light theme.", log: log, type: .debug)
                 case "dark":
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                    os_log("Applied Dark theme.", log: log, type: .debug)
                 default:
                    NSApp.appearance = nil
                    os_log("Applied System theme.", log: log, type: .debug)
                 }
             } else {
                os_log("Theme switching only available on macOS 10.14+", log: log, type: .info)
             }
        }
    }

    func stringFromKeyCode(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        // This is the original logic from the user-provided file in the immersive artifact
        var displayString = ""
        if modifiers.contains(.control) { displayString += "⌃" }
        if modifiers.contains(.option) { displayString += "⌥" }
        if modifiers.contains(.shift) { displayString += "⇧" }
        if modifiers.contains(.command) { displayString += "⌘" }
        switch keyCode {
            case kVK_Tab: displayString += "Tab"; case kVK_Space: displayString += "Space"; case kVK_Return: displayString += "Return"; case kVK_Escape: displayString += "Esc"; case kVK_Delete: displayString += "Delete"; case kVK_ForwardDelete: displayString += "Fwd Del";
            case kVK_ANSI_A: displayString += "A"; case kVK_ANSI_B: displayString += "B"; case kVK_ANSI_C: displayString += "C"; case kVK_ANSI_D: displayString += "D"; case kVK_ANSI_E: displayString += "E"; case kVK_ANSI_F: displayString += "F"; case kVK_ANSI_G: displayString += "G"; case kVK_ANSI_H: displayString += "H"; case kVK_ANSI_I: displayString += "I"; case kVK_ANSI_J: displayString += "J"; case kVK_ANSI_K: displayString += "K"; case kVK_ANSI_L: displayString += "L"; case kVK_ANSI_M: displayString += "M"; case kVK_ANSI_N: displayString += "N"; case kVK_ANSI_O: displayString += "O"; case kVK_ANSI_P: displayString += "P"; case kVK_ANSI_Q: displayString += "Q"; case kVK_ANSI_R: displayString += "R"; case kVK_ANSI_S: displayString += "S"; case kVK_ANSI_T: displayString += "T"; case kVK_ANSI_U: displayString += "U"; case kVK_ANSI_V: displayString += "V"; case kVK_ANSI_W: displayString += "W"; case kVK_ANSI_X: displayString += "X"; case kVK_ANSI_Y: displayString += "Y"; case kVK_ANSI_Z: displayString += "Z";
            case kVK_ANSI_0: displayString += "0"; case kVK_ANSI_1: displayString += "1"; case kVK_ANSI_2: displayString += "2"; case kVK_ANSI_3: displayString += "3"; case kVK_ANSI_4: displayString += "4"; case kVK_ANSI_5: displayString += "5"; case kVK_ANSI_6: displayString += "6"; case kVK_ANSI_7: displayString += "7"; case kVK_ANSI_8: displayString += "8"; case kVK_ANSI_9: displayString += "9";
            // The original code from the artifact did not have the more complex default case with UInt16 conversion.
            // It simply had:
            default: displayString += "Key \(keyCode)"
        }
        return displayString
    }
}

extension Notification.Name {
    static let shortcutPreferenceChanged = Notification.Name("com.pogorielov.BetterTab.shortcutPreferenceChanged") // Using a more specific name
    static let appBindingsChanged = Notification.Name("com.pogorielov.BetterTab.appBindingsChanged")
    static let appearancePreferenceChanged = Notification.Name("com.pogorielov.BetterTab.appearancePreferenceChanged")
}

extension NSColor {
    var hexString: String? {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            os_log("Could not convert color to sRGB for hex string generation.", log: log, type: .default)
            return nil
        }
        let red = Int(round(rgbColor.redComponent * 255.0))
        let green = Int(round(rgbColor.greenComponent * 255.0))
        let blue = Int(round(rgbColor.blueComponent * 255.0))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
