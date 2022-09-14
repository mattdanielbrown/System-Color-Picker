import SwiftUI
import Defaults

/**
NOTES:
- The "com.apple.security.files.user-selected.read-only" entitlement is required by the "Open" menu in the "Color Palettes" pane.
*/

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general, onlyWhileAppIsActive: true)

	init() {
		migrate()
	}

	var body: some Scene {
		WindowGroup {
			if false {}
		}
			// TODO: How to replace `File` menu with `Color`?
			// TODO: Would be nice to be able to remove the `View` menu: https://github.com/feedback-assistant/reports/issues/252
			.commands {
				CommandGroup(replacing: .newItem) {}
				CommandMenu("Color") {
					Button("Pick") {
						appState.pickColor()
					}
						.keyboardShortcut("p")
					Divider()
					Button("Copy as Hex") {
						appState.colorPanel.color.hexColorString.copyToPasteboard()
					}
						.keyboardShortcut("h", modifiers: [.shift, .command])
					Button("Copy as HSL") {
						appState.colorPanel.color.hslColorString.copyToPasteboard()
					}
						.keyboardShortcut("s", modifiers: [.shift, .command])
					Button("Copy as RGB") {
						appState.colorPanel.color.rgbColorString.copyToPasteboard()
					}
						.keyboardShortcut("r", modifiers: [.shift, .command])
					Button("Copy as LCH") {
						appState.colorPanel.color.lchColorString.copyToPasteboard()
					}
						.keyboardShortcut("l", modifiers: [.shift, .command])
					Button("Paste") {
						appState.pasteColor()
					}
						.help("Paste color in the format Hex, HSL, RGB, or LCH")
						.keyboardShortcut("v", modifiers: [.shift, .command])
						.disabled(NSColor.fromPasteboardGraceful(.general) == nil)
				}
				CommandGroup(replacing: .help) {
					Link("What is LCH color?", destination: "https://lea.verou.me/2020/04/lch-colors-in-css-what-why-and-how/")
					Link("FAQ", destination: "https://github.com/sindresorhus/System-Color-Picker#faq")
					Link("Website", destination: "https://sindresorhus.com/system-color-picker")
					Divider()
					Link("Rate on the App Store", destination: "macappstore://apps.apple.com/app/id1545870783?action=write-review")
					Link("More Apps by Me", destination: "macappstore://apps.apple.com/developer/id328077650")
					Divider()
					Button("Send Feedback…") {
						SSApp.openSendFeedbackPage()
					}
				}
			}
		Settings {
			SettingsScreen()
		}
	}

	private func migrate() {
		// TODO: Remove in 2023.
		SSApp.runOnce(identifier: "migrateShownColorFormats") {
			guard !SSApp.isFirstLaunch else {
				return
			}

			Defaults.migrate(.shownColorFormats, to: .v5)
			Defaults.migrate(.colorFormatToCopyAfterPicking, to: .v5)
		}

		// TODO: Remove in 2023.
		SSApp.runOnce(identifier: "migrateToPreferredColorFormatSetting") {
			guard !SSApp.isFirstLaunch else {
				return
			}

			if Defaults[.colorFormatToCopyAfterPicking] != .none {
				Defaults[.copyColorAfterPicking] = true
			}

			switch Defaults[.colorFormatToCopyAfterPicking] {
			case .none:
				break
			case .hex:
				Defaults[.preferredColorFormat] = .hex
			case .hsl:
				Defaults[.preferredColorFormat] = .hsl
			case .rgb:
				Defaults[.preferredColorFormat] = .rgb
			case .lch:
				Defaults[.preferredColorFormat] = .lch
			}
		}

		// Preserve the old behavior for existing users.
		SSApp.runOnce(identifier: "setDefaultsForMenuBarItemClickActionSetting") {
			guard !SSApp.isFirstLaunch else {
				return
			}

			Defaults[.menuBarItemClickAction] = .toggleWindow
		}
	}
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		if #available(macOS 13, *) {
			SSApp.swiftUIMainWindow?.close()
		}
	}

	// Does not work on macOS 12.0.1 because of `WindowGroup`: https://github.com/feedback-assistant/reports/issues/246
	// This is only run when the app is started when it's already running.
//	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
//		AppState.shared.handleAppReopen()
//		return true
//	}
}
