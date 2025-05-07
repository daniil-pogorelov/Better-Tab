import Foundation

// This struct holds application-wide constants.
struct Constants {

    // MARK: - Launch at Login (for macOS < 13)

    /**
     * Bundle identifier for a separate helper application used for the "Launch at Login" feature
     * on macOS versions older than 13.0.
     *
     * - Important: This identifier MUST match the `CFBundleIdentifier` of a dedicated lightweight
     * launcher helper application that you include in your main app's bundle
     * (e.g., within `Contents/Library/LoginItems`).
     * The `SMLoginItemSetEnabled` function (used as a fallback in `AppDelegate` for older macOS)
     * relies on this helper application.
     *
     * - Note: For macOS 13.0 and newer, `SMAppService.mainApp.register()` is used, which
     * manages login items directly for the main application and does *not* require this
     * separate helper or its bundle identifier.
     *
     * - If you do not provide a helper application, the "Launch at Login" feature
     * will likely not function correctly on macOS versions prior to 13.0.
     * The current value is an example and should be replaced with your actual helper app's ID.
     */
    static let launcherAppBundleIdentifier = "com.pogorielov.BetterTabLauncher" // FIXME: Replace with your actual helper app's bundle ID if supporting launch at login on macOS < 13.

    // MARK: - Other Constants
    // Add other app-wide constants here as needed.
    // For example:
    // static let appWebsiteURL = URL(string: "https://www.example.com/bettertab")
    // static let supportEmailAddress = "danilpogorielov@icloud.com"

}
