//
//  OnePlus_Buds_MenuApp.swift
//  OnePlus Buds Menu
//
//  Created by Saket Joshi on 19/07/26.
//

import SwiftUI
import AppKit
import Combine
import ServiceManagement

@main
struct OnePlusBudsMenuApp: App {
    @StateObject private var controller = BudsCommandController()
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some Scene {
        MenuBarExtra {
            BudsPanelView(controller: controller, launchAtLogin: launchAtLogin)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "earbuds.in.ear")

                if let menuBarBatteryText {
                    Text(menuBarBatteryText)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarBatteryText: String? {
        controller.displayBattery?.totalWeightedPercent.map { "\($0)%" }
    }
}

private struct BudsPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettingsExpanded = false

    @ObservedObject var controller: BudsCommandController
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(headerTitle)
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

                Text("Battery")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.paperSecondaryTextGradient)

                HStack(alignment: .top, spacing: 12) {
                    BatteryMetricView(
                        metric: .total,
                        title: "Total",
                        percentage: controller.displayBattery?.totalWeightedPercent
                    )
                    BatteryMetricView(
                        metric: .left,
                        title: "Left",
                        percentage: controller.battery?.left
                    )
                    BatteryMetricView(
                        metric: .right,
                        title: "Right",
                        percentage: controller.battery?.right
                    )
                }

                PaperDivider()

                Button {
                    withAnimation(standardSpring) {
                        isSettingsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Settings")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.paperSecondaryTextGradient)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.paperSecondaryTextGradient)
                            .rotationEffect(.degrees(isSettingsExpanded ? 0 : -90))
                            .animation(standardSpring, value: isSettingsExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isSettingsExpanded ? "Hide settings" : "Show settings")

                if isSettingsExpanded {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Launch on login")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.paperSecondaryTextGradient)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        PaperToggle(
                            isOn: Binding(
                                get: { launchAtLogin.isEnabled },
                                set: { launchAtLogin.setEnabled($0) }
                            ),
                            status: launchAtLogin.accessibilityStatus
                        )
                    }
                    .frame(height: 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    .help(launchAtLogin.errorMessage ?? "Open OnePlus Buds Menu automatically when you sign in")
                }

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
        .animation(standardSpring, value: isSettingsExpanded)
        .animation(standardSpring, value: controller.isCommandReady)
        .onAppear {
            controller.refreshBatteryIfNeeded()
        }
    }

    private var deviceTitle: String {
        controller.deviceName ?? "Saket's oneplus buds 4"
    }

    private var headerTitle: String {
        deviceTitle
    }

    private var panelBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.08)
    }

    private var panelShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.55 : 0.18)
    }

    private var standardSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.36, dampingFraction: 0.82)
    }

}

@MainActor
private final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var errorMessage: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    var accessibilityStatus: String {
        if let errorMessage {
            return errorMessage
        }

        return isEnabled ? "Enabled" : "Disabled"
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            isEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = nil
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = "Could not update launch at login"
            print("Failed to update launch at login: \(error.localizedDescription)")
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isOn ? .paperToggleActiveTrack : .paperToggleTrack)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(configuration.isOn ? .white : Color.paperToggleThumb)
                    .frame(width: 12, height: 12)
                    .padding(2)
                    .shadow(color: Color.black.opacity(configuration.isOn ? 0.10 : 0.16), radius: 1, y: 0.5)
            }
            .frame(width: 30, height: 16)
            .animation(toggleSpring, value: configuration.isOn)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var toggleSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.32, dampingFraction: 0.72)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let mode: NoiseControlMode
    let isSelected: Bool
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var iconName: String {
        switch mode {
        case .noiseCancellation:
            return "person.circle"
        case .transparency:
            return "person.2.circle"
        case .off:
            return "speaker.slash.fill"
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
                    .scaleEffect(isSelected || isLoading ? 1 : 0.94)
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
                                .transition(loadingTransition)
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
            .animation(selectionSpring, value: isSelected)
            .animation(selectionSpring, value: isLoading)
        }
        .buttonStyle(PaperPressButtonStyle())
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

    private var selectionSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.78)
    }

    private var loadingTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.82))
    }
}

private enum BatteryMetric {
    case total
    case left
    case right

    func symbolName(for percentage: Int?) -> String {
        switch self {
        case .left:
            return "earbud.left"
        case .right:
            return "earbud.right"
        case .total:
            guard let percentage else { return "battery.0percent" }
            switch percentage {
            case ..<13: return "battery.0percent"
            case ..<38: return "battery.25percent"
            case ..<63: return "battery.50percent"
            case ..<88: return "battery.75percent"
            default: return "battery.100percent"
            }
        }
    }
}

private struct BatteryMetricView: View {
    let metric: BatteryMetric
    let title: String
    let percentage: Int?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: metric.symbolName(for: percentage))
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.paperInactiveIcon)
                .frame(width: 43, height: 43)
                .background(Circle().fill(Color.paperInactiveControl))

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.paperSecondaryTextGradient)

                Text(percentage.map { "\($0)%" } ?? "—")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.paperSelectedTextGradient)
                    .monospacedDigit()
            }
        }
        .frame(width: 70)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(percentage.map { "\($0) percent" } ?? "Unavailable")
    }
}

private struct PaperPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.22, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

private extension Color {
    static let paperPanel = dynamicColor(
        light: NSColor(red: 245 / 255, green: 245 / 255, blue: 242 / 255, alpha: 1),
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
    static var paperToggleActiveTrack: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 255 / 255, green: 106 / 255, blue: 0), location: 0),
                .init(color: Color(red: 194 / 255, green: 79 / 255, blue: 2 / 255), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var paperToggleTrack: LinearGradient {
        LinearGradient(
            colors: [Color.paperToggleTrack],
            startPoint: .top,
            endPoint: .bottom
        )
    }

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
