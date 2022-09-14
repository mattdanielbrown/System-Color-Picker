import SwiftUI
import Defaults

private struct RecentlyPickedColorsButton: View {
	@EnvironmentObject private var appState: AppState
	@Default(.recentlyPickedColors) private var recentlyPickedColors

	// TODO: Find a better way to handle this than having to subscribe to each key.
	@Default(.preferredColorFormat) private var preferredColorFormat // Only to get updates
	@Default(.uppercaseHexColor) private var uppercaseHexColor // Only to get updates
	@Default(.hashPrefixInHexColor) private var hashPrefixInHexColor // Only to get updates
	@Default(.legacyColorSyntax) private var legacyColorSyntax // Only to get updates

	var body: some View {
		Menu {
			Group {
				ForEach(recentlyPickedColors.reversed()) { color in
					Button {
						appState.colorPanel.color = color
					} label: {
						Label {
							Text(color.stringRepresentation)
						} icon: {
							// We don't use SwiftUI here as it only supports showing an actual image. (macOS 12.0)
							// https://github.com/feedback-assistant/reports/issues/247
							Image(nsImage: color.swatchImage)
						}
							.labelStyle(.titleAndIcon)
					}
				}
				Divider()
				Button("Clear") {
					recentlyPickedColors = []
				}
			}
				// TODO: Remove when targeting macOS 13 where it's fixed.
				// Without, it becomes disabled. (macOS 12.4)
				.buttonStyle(.automatic)
		} label: {
			Image(systemName: "clock.fill")
				.controlSize(.large)
//				.padding(8) // Has no effect. (macOS 12.0.1)
				.contentShape(.rectangle)
		}
			.menuIndicator(.hidden)
			.padding(8)
			.fixedSize()
			.opacity(0.6) // Try to match the other buttons.
			.disabled(recentlyPickedColors.isEmpty)
			.help(recentlyPickedColors.isEmpty ? "No recently picked colors" : "Recently picked colors")
	}
}

private struct BarView: View {
	@Environment(\.colorScheme) private var colorScheme
	@EnvironmentObject private var appState: AppState
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general).stop()
	@Default(.showInMenuBar) private var showInMenuBar

	var body: some View {
		HStack(spacing: 12) {
			Button {
				appState.pickColor()
			} label: {
				Image(systemName: "eyedropper")
					.font(.system(size: 14).bold())
					.padding(8)
			}
				.contentShape(.rectangle)
				.help("Pick color")
				.keyboardShortcut("p")
				.padding(.leading, 4)
			Button {
				appState.pasteColor()
			} label: {
				Image(systemName: "paintbrush.fill")
					.padding(8)
			}
				.contentShape(.rectangle)
				.help("Paste color in the format Hex, HSL, RGB, or LCH")
				.keyboardShortcut("v", modifiers: [.shift, .command])
				.disabled(NSColor.fromPasteboardGraceful(.general) == nil)
			RecentlyPickedColorsButton()
			moreButton
			Spacer()
		}
			// Cannot do this as the `Menu` buttons don't respect it. (macOS 12.0.1)
			// https://github.com/feedback-assistant/reports/issues/249
//			.font(.title3)
			.background {
				RoundedRectangle(cornerRadius: 6, style: .continuous)
					.fill(Color.black.opacity(colorScheme == .dark ? 0.17 : 0.05))
			}
			.padding(.vertical, 4)
			.buttonStyle(.borderless)
			.menuStyle(.borderlessButton)
			.onAppearOnScreen {
				pasteboardObserver.start()
			}
			.onDisappearFromScreen {
				pasteboardObserver.stop()
			}
	}

	private var moreButton: some View {
		Menu {
			Button("Copy as HSB") {
				appState.colorPanel.color.hsbColorString.copyToPasteboard()
			}
			if showInMenuBar {
				Divider()
				Button(OS.isMacOS13OrLater ? "Settings…" : "Preferences…") {
					SSApp.showSettingsWindow()
				}
					.keyboardShortcut(",")
			}
		} label: {
			Label("More", systemImage: "ellipsis.circle.fill")
				.labelStyle(.iconOnly)
//				.padding(8) // Has no effect. (macOS 12.0.1)
		}
			// TODO: Remove when targeting macOS 13 where it's fixed.
			.buttonStyle(.automatic) // Without, it becomes disabled: https://github.com/feedback-assistant/reports/issues/250 (macOS 12.0.1)
			.padding(8)
			.contentShape(.rectangle)
			.fixedSize()
			.opacity(0.6) // Try to match the other buttons.
			.menuIndicator(.hidden)
	}
}

struct ColorPickerScreen: View {
	@EnvironmentObject private var appState: AppState
	@Default(.uppercaseHexColor) private var uppercaseHexColor
	@Default(.hashPrefixInHexColor) private var hashPrefixInHexColor
	@Default(.legacyColorSyntax) private var legacyColorSyntax
	@Default(.shownColorFormats) private var shownColorFormats
	@Default(.largerText) private var largerText
	@State private var hexColor = ""
	@State private var hslColor = ""
	@State private var rgbColor = ""
	@State private var lchColor = ""
	@State private var isTextFieldFocusedHex = false
	@State private var isTextFieldFocusedHSL = false
	@State private var isTextFieldFocusedRGB = false
	@State private var isTextFieldFocusedLCH = false
	@State private var isPreventingUpdate = false

	let colorPanel: NSColorPanel

	private var isAnyTextFieldFocused: Bool {
		isTextFieldFocusedHex
			|| isTextFieldFocusedHSL
			|| isTextFieldFocusedRGB
			|| isTextFieldFocusedLCH
	}

	private var textFieldFontSize: Double { largerText ? 16 : 0 }

	private var hexColorView: some View {
		HStack {
			// TODO: When I use `TextField`, add the copy button using `.safeAreaInset()`.
			NativeTextField(
				text: $hexColor,
				placeholder: "Hex",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocusedHex
			)
				.controlSize(.large)
				.onChange(of: hexColor) {
					var hexColor = $0

					if hexColor.hasPrefix("##") {
						hexColor = hexColor.dropFirst().toString
						self.hexColor = hexColor
					}

					if
						isTextFieldFocusedHex,
						!isPreventingUpdate,
						let newColor = NSColor(hexString: hexColor.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeHex: true, preventUpdate: true)
					}
				}
			Button("Copy Hex", systemImage: "doc.on.doc.fill") {
				appState.colorPanel.color.hexColorString.copyToPasteboard()
			}
				.labelStyle(.iconOnly)
				.symbolRenderingMode(.hierarchical)
				.buttonStyle(.borderless)
				.contentShape(.rectangle)
				.keyboardShortcut("h", modifiers: [.shift, .command])
		}
	}

	private var hslColorView: some View {
		HStack {
			NativeTextField(
				text: $hslColor,
				placeholder: "HSL",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocusedHSL
			)
				.controlSize(.large)
				.onChange(of: hslColor) {
					if
						isTextFieldFocusedHSL,
						!isPreventingUpdate,
						let newColor = NSColor(cssHSLString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeHSL: true, preventUpdate: true)
					}
				}
			Button("Copy HSL", systemImage: "doc.on.doc.fill") {
				hslColor.copyToPasteboard()
			}
				.labelStyle(.iconOnly)
				.symbolRenderingMode(.hierarchical)
				.buttonStyle(.borderless)
				.contentShape(.rectangle)
				.keyboardShortcut("s", modifiers: [.shift, .command])
		}
	}

	private var rgbColorView: some View {
		HStack {
			NativeTextField(
				text: $rgbColor,
				placeholder: "RGB",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocusedRGB
			)
				.controlSize(.large)
				.onChange(of: rgbColor) {
					if
						isTextFieldFocusedRGB,
						!isPreventingUpdate,
						let newColor = NSColor(cssRGBString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeRGB: true, preventUpdate: true)
					}
				}
			Button("Copy RGB", systemImage: "doc.on.doc.fill") {
				rgbColor.copyToPasteboard()
			}
				.labelStyle(.iconOnly)
				.symbolRenderingMode(.hierarchical)
				.buttonStyle(.borderless)
				.contentShape(.rectangle)
				.keyboardShortcut("r", modifiers: [.shift, .command])
		}
	}

	private var lchColorView: some View {
		HStack {
			NativeTextField(
				text: $lchColor,
				placeholder: "LCH",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocusedLCH
			)
				.controlSize(.large)
				.onChange(of: lchColor) {
					if
						isTextFieldFocusedLCH,
						!isPreventingUpdate,
						let newColor = NSColor(cssLCHString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeLCH: true, preventUpdate: true)
					}
				}
			Button("Copy LCH", systemImage: "doc.on.doc.fill") {
				lchColor.copyToPasteboard()
			}
				.labelStyle(.iconOnly)
				.symbolRenderingMode(.hierarchical)
				.buttonStyle(.borderless)
				.contentShape(.rectangle)
				.keyboardShortcut("l", modifiers: [.shift, .command])
		}
	}

	var body: some View {
		VStack {
			BarView()
			if shownColorFormats.contains(.hex) {
				hexColorView
			}
			if shownColorFormats.contains(.hsl) {
				hslColorView
			}
			if shownColorFormats.contains(.rgb) {
				rgbColorView
			}
			if shownColorFormats.contains(.lch) {
				lchColorView
			}
		}
			.padding(9)
			// 244 makes `HSL` always fit in the text field.
			.frame(minWidth: 244, maxWidth: .infinity)
			.task {
				updateColorsFromPanel()
			}
			.onChange(of: uppercaseHexColor) { _ in
				updateColorsFromPanel()
			}
			.onChange(of: hashPrefixInHexColor) { _ in
				updateColorsFromPanel()
			}
			.onChange(of: legacyColorSyntax) { _ in
				updateColorsFromPanel()
			}
			.onReceive(colorPanel.colorDidChangePublisher) {
				guard !isAnyTextFieldFocused else {
					return
				}

				updateColorsFromPanel(preventUpdate: true)
			}
	}

	// TODO: Find a better way to handle this.
	private func updateColorsFromPanel(
		excludeHex: Bool = false,
		excludeHSL: Bool = false,
		excludeRGB: Bool = false,
		excludeLCH: Bool = false,
		preventUpdate: Bool = false
	) {
		if preventUpdate {
			isPreventingUpdate = true
		}

		let color = colorPanel.color

		if !excludeHex {
			hexColor = color.hexColorString
		}

		if !excludeHSL {
			hslColor = color.hslColorString
		}

		if !excludeRGB {
			rgbColor = color.rgbColorString
		}

		if !excludeLCH {
			lchColor = color.lchColorString
		}

		if preventUpdate {
			DispatchQueue.main.async {
				isPreventingUpdate = false
			}
		}
	}
}

struct ColorPickerScreen_Previews: PreviewProvider {
	static var previews: some View {
		ColorPickerScreen(colorPanel: .shared)
	}
}
