//
//  OnePlus_Buds_MenuApp.swift
//  OnePlus Buds Menu
//
//  Created by Saket Joshi on 19/07/26.
//

import SwiftUI
import AppKit

@main
struct OnePlusBudsMenuApp: App {
    @StateObject private var controller = BudsCommandController()

    var body: some Scene {
        MenuBarExtra("OnePlus Buds", systemImage: "headphones") {
            BudsPanelView(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct BudsPanelView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var controller: BudsCommandController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(deviceTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.paperSecondaryTextGradient)
                .frame(maxWidth: .infinity, alignment: .leading)

                PaperToggle(
                    isOn: Binding(
                        get: { controller.isConnectionEnabled },
                        set: { _ in controller.toggleConnection() }
                    ),
                    status: controller.connectionAccessibilityStatus
                )
            }

            PaperDivider()

            if controller.isCommandReady {
                Text("Noise control")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.paperSecondaryTextGradient)

                HStack(alignment: .top, spacing: 12) {
                    ForEach(NoiseControlMode.allCases) { mode in
                        NoiseControlOptionButton(
                            mode: mode,
                            isSelected: controller.selectedMode == mode,
                            isLoading: controller.pendingMode == mode,
                            isEnabled: controller.isCommandReady && !controller.isChangingNoiseControl
                        ) {
                            controller.select(mode)
                        }
                    }
                }

                PaperDivider()
            } else if controller.isConnecting || controller.isConnected {
                Text(controller.status)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.paperSecondaryTextGradient)

                PaperDivider()
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit app")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.paperSecondaryTextGradient)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quit app")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.paperPanel)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(panelBorderColor, lineWidth: 1)
                }
                .shadow(color: panelShadowColor, radius: 35, x: 0, y: 24)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 9, x: 0, y: 4)
        )
    }

    private var deviceTitle: String {
        controller.deviceName ?? "Saket's oneplus buds 4"
    }

    private var panelBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.08)
    }

    private var panelShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.55 : 0.18)
    }
}

private struct PaperToggle: View {
    @Binding var isOn: Bool
    let status: String

    var body: some View {
        Toggle("Earbuds connection", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(PaperToggleStyle())
            .help(isOn ? "Disconnect earbuds" : "Connect earbuds")
            .accessibilityLabel("Earbuds connection")
            .accessibilityValue(status)
    }
}

private struct PaperToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.paperToggleTrack)
                .frame(width: 30, height: 16)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(configuration.isOn ? Color.paperSelected : Color.paperToggleThumb)
                        .frame(width: 12, height: 12)
                        .padding(.horizontal, 2)
                }
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PaperDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.paperDivider)
            .frame(height: 1)
    }
}

private struct NoiseControlOptionButton: View {
    let mode: NoiseControlMode
    let isSelected: Bool
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var iconName: String {
        switch mode {
        case .noiseCancellation:
            return "person.crop.circle"
        case .transparency:
            return "person.crop.circle.badge.checkmark"
        case .off:
            return "speaker.slash"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.paperInactiveIcon)
                    .frame(width: 43, height: 43)
                    .background(
                        Circle()
                            .fill(controlColor)
                    )
                    .opacity(isLoading ? 0 : 1)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .progressViewStyle(.circular)
                                .tint(Color.white.opacity(0.9))
                                .frame(width: 43, height: 43)
                                .background(
                                    Circle()
                                        .fill(selectedColor)
                                )
                        }
                    }

                Text(mode.title)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle((isSelected || isLoading) ? .paperSelectedTextGradient : .paperSecondaryTextGradient)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 70, alignment: .top)
            }
            .frame(width: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(isLoading ? "Changing to \(mode.title)" : mode.title)
        .accessibilityLabel(mode.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var accessibilityValue: String {
        if isLoading {
            return "Changing"
        }

        if !isEnabled {
            return "Unavailable"
        }

        return isSelected ? "Selected" : "Not selected"
    }

    private var controlColor: Color {
        isSelected ? selectedColor : unselectedColor
    }

    private var selectedColor: Color {
        Color.paperSelected
    }

    private var unselectedColor: Color {
        Color.paperInactiveControl
    }
}

private extension Color {
    static let paperPanel = dynamicColor(
        light: NSColor(red: 240 / 255, green: 240 / 255, blue: 237 / 255, alpha: 1),
        dark: NSColor(red: 31 / 255, green: 31 / 255, blue: 29 / 255, alpha: 1)
    )

    static let paperSelected = Color(red: 255 / 255, green: 106 / 255, blue: 0 / 255)

    static let paperInactiveControl = dynamicColor(
        light: NSColor(red: 229 / 255, green: 229 / 255, blue: 225 / 255, alpha: 1),
        dark: NSColor(red: 55 / 255, green: 55 / 255, blue: 51 / 255, alpha: 1)
    )

    static let paperTextBase = dynamicColor(
        light: NSColor(red: 15 / 255, green: 15 / 255, blue: 16 / 255, alpha: 1),
        dark: NSColor(red: 246 / 255, green: 245 / 255, blue: 238 / 255, alpha: 1)
    )

    static let paperSecondaryText = paperTextBase.opacity(0.65)

    static let paperSelectedText = paperTextBase.opacity(0.90)

    static let paperCloseText = paperSecondaryText

    static let paperInactiveIcon = dynamicColor(
        light: NSColor(red: 110 / 255, green: 110 / 255, blue: 115 / 255, alpha: 0.9),
        dark: NSColor(red: 196 / 255, green: 195 / 255, blue: 188 / 255, alpha: 0.9)
    )

    static let paperDivider = dynamicColor(
        light: NSColor(red: 110 / 255, green: 110 / 255, blue: 115 / 255, alpha: 0.10),
        dark: NSColor(red: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 0.10)
    )

    static let paperToggleTrack = dynamicColor(
        light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.14),
        dark: NSColor(red: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 0.16)
    )

    static let paperToggleThumb = dynamicColor(
        light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.36),
        dark: NSColor(red: 246 / 255, green: 245 / 255, blue: 238 / 255, alpha: 0.62)
    )

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode ? dark : light
        })
    }
}

private extension ShapeStyle where Self == LinearGradient {
    static var paperSecondaryTextGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.paperTextBase.opacity(0.40), location: 0),
                .init(color: Color.paperSecondaryText, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var paperSelectedTextGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.paperTextBase.opacity(0.60), location: 0),
                .init(color: Color.paperSelectedText, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
