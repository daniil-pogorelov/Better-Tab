import AppKit // Or import Cocoa

// --- VERY EARLY LOGGING ---
print("main.swift: Starting execution...")

// --- Explicitly set the delegate ---
// Create an instance of our AppDelegate
let delegate = AppDelegate()
// Assign it as the delegate to the shared NSApplication instance.
// NSApplication.shared refers to the singleton application instance.
NSApplication.shared.delegate = delegate
print("main.swift: Explicitly set NSApplication.shared.delegate to AppDelegate instance.")

// This file provides the main entry point for the application when not using @main or storyboards.

// NSApplicationMain initializes the application, loads the principal class
// specified in Info.plist (which should be NSApplication now), *uses the delegate we just set*,
// and starts the event loop.
// Argc and Argv are the standard C command-line arguments.
print("main.swift: Calling NSApplicationMain...")
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

// This line will likely not be reached as NSApplicationMain starts the run loop
print("main.swift: NSApplicationMain has returned (unexpected).")
