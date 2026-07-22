//
//  TextReamApp.swift
//  TextReam
//  Created by Hudson Nicoletti on 20/07/26.
//

import SwiftUI
import AppKit

@main
/// Defines the app scene and connects the control window to shared state.
struct TextreamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TeleprompterModel()

    /// Builds the control scene and connects lifecycle events to permission and overlay updates.
    var body: some Scene {
        WindowGroup("Textream") {
            ControlView()
                .environmentObject(model)
                .frame(minWidth: 520, minHeight: 560)
                .onAppear {
                    model.requestMicrophonePermissionOnLaunch()
                    appDelegate.bind(model)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    model.refreshMicrophonePermission()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Prompter") {
                Button("Back") { model.nudge(-120) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("Forward") { model.nudge(120) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("Reset") { model.reset() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
            }
        }
    }
}

/// Bridges SwiftUI startup to AppKit and owns the notch overlay controller.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: NotchOverlayController?

    /// Makes Textream a regular Dock app after AppKit finishes launching.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    @MainActor
    /// Connects the shared model to `NotchOverlayController` and shows its panel.
    func bind(_ model: TeleprompterModel) {
        if overlay == nil { overlay = NotchOverlayController(model: model) }
        overlay?.show()
    }
}
