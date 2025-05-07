# BetterTab - The Smarter macOS App Switcher

BetterTab is a macOS application designed to enhance your app switching experience. It provides a customizable, quick-launch overlay for your running applications and allows you to define app-specific hotkeys for instant access to your favorite apps.

## Core Features

* **Enhanced App Switcher:** Activate a sleek overlay displaying your running applications using a configurable global hotkey (default: `Option+Tab`).
* **Quick Filtering:** Instantly filter the list of running applications by typing parts of their name. Supports both prefix and fuzzy search.
* **App-Specific Hotkeys (App Binds):** Define custom keyboard shortcuts to launch or switch to specific applications directly, bypassing the main switcher.
* **Customizable Appearance:** Choose between System, Light, or Dark themes for the BetterTab preferences window.
* **Launch at Login:** Optionally have BetterTab start automatically when you log into your Mac.
* **Status Bar Access:** Conveniently access preferences and quit the application via a status bar menu icon.
* **Accessibility Focused:** Designed to integrate with macOS accessibility features for keyboard event monitoring.

## How to Use

1.  **Activation:**
    * **Global App Switcher:** Press your configured global hotkey (default is `Option+Tab`). The BetterTab switcher overlay will appear.
    * **App-Specific Hotkeys:** Once configured in "App Binds" preferences, press the custom shortcut for an application to launch it or bring it to the front.

2.  **Using the Global App Switcher:**
    * While the switcher is active:
        * Press `Tab` to cycle forward through applications.
        * Press `Shift+Tab` to cycle backward.
        * Start typing an application's name to filter the list.
        * Press `Escape` to dismiss the switcher without making a selection.
    * Release the global hotkey's primary modifier (e.g., `Option` if your shortcut is `Option+Tab`) to activate the currently selected application in the switcher.

## Preferences

Access preferences via the status bar menu icon or by pressing `Command+,` when the app is active (if it has a main menu visible).

### 1. General
   * **Global Shortcut:** Customize the keyboard shortcut used to activate the main BetterTab app switcher.
        * Click "Change..." and type your desired combination (must include Command, Control, or Option).
   * **Enable Fuzzy Search in Switcher:** When checked, typing in the switcher will match apps containing the typed characters anywhere in their name. If unchecked, it will only match apps whose names start with the typed characters.
   * **Launch App at Login:** If checked, BetterTab will start automatically when you log into your Mac.

### 2. Appearance
   * **Theme:** Select the appearance for the BetterTab preferences window.
        * **System:** Follows your macOS system appearance.
        * **Light:** Always uses the light appearance.
        * **Dark:** Always uses the dark appearance.

### 3. App Binds
   This powerful feature allows you to set custom keyboard shortcuts to launch or switch to specific applications directly.
   * **Adding an App:**
        1.  Click the `+` button.
        2.  In the open panel, navigate to and select the desired `.app` file (e.g., Safari.app, Notes.app).
        3.  The application will be added to the list.
   * **Setting/Changing a Shortcut:**
        1.  Select an application in the list.
        2.  Click the "Set Shortcut" button.
        3.  The "Shortcut" cell will display "Type shortcut...".
        4.  Press your desired keyboard combination for this app.
        5.  To clear a shortcut, trigger the recording and press `Escape`.
   * **Removing an App Binding:**
        1.  Select an application in the list.
        2.  Click the `-` button.

## Installation

*(This section is a placeholder. For a typical GitHub release, you might provide a .dmg or a .zip containing the compiled .app file.)*

1.  Download the latest `BetterTab.app` from the [Releases page](https://github.com/daniil-pogorelov/BetterTab/releases).
2.  Drag `BetterTab.app` to your `/Applications` folder.
3.  On first launch, macOS will likely ask for Accessibility permissions. Please grant these for BetterTab to function correctly. You can manage these in `System Settings > Privacy & Security > Accessibility`.

## Building from Source

1.  Clone the repository:
    ```bash
    git clone [https://github.com/YOUR_USERNAME/BetterTab.git](https://github.com/YOUR_USERNAME/BetterTab.git)
    cd BetterTab
    ```
2.  Open `BetterTab.xcodeproj` in Xcode.
3.  Select the "BetterTab" scheme and your desired build target (e.g., "My Mac").
4.  Click the "Build and then run" button (or `Cmd+R`).

**Requirements:**
* macOS 14.0 or later
* Xcode 16 or later

## Troubleshooting

* **Shortcuts Not Working:**
    * Ensure BetterTab has Accessibility permissions in `System Settings > Privacy & Security > Accessibility`. You may need to remove and re-add BetterTab if issues persist.
    * Check that the "Enable App Switcher" (or similar, if you add such a toggle) is on.
    * Verify that no other application is using the same global hotkeys.
* **App Binds Not Triggering:**
    * Double-check the exact key combination recorded in the App Binds preferences.
    * Ensure BetterTab's event tap is active (related to Accessibility permissions).

## Future Ideas & Contributing

* [ ] More visual customization options for the switcher overlay (size, colors, fonts).
* [ ] Option to exclude certain apps from the global switcher.
* [ ] Display app icons more prominently in the "App Binds" list.
* [ ] Support for binding scripts or system commands in addition to apps.
* [ ] More robust error handling and user feedback.

Contributions are welcome! Please feel free to fork the repository, make changes, and submit a pull request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
