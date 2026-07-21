//
//  OnePlus_Buds_MenuApp.swift
//  OnePlus Buds Menu
//
//  Created by Saket Joshi on 19/07/26.
//

import AppKit
import SwiftUI

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
                    label: "Earbuds connection",
                    status: controller.connectionAccessibilityStatus,
                    enabledHelp: "Disconnect earbuds",
                    disabledHelp: "Connect earbuds"
                )
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)

                Text(controller.phase.statusText)
                    .font(.caption)
                    .foregroundStyle(Color.paperSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if controller.phase.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(controller.phase.statusText)
                } else if controller.canRetry {
                    Button("Retry") {
                        controller.retry()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.paperSelected)
                    .accessibilityHint("Attempts to reconnect to the earbuds")
                }
            }
            .accessibilityElement(children: .combine)

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
            }

            Button {
                withAnimation(standardSpring) {
                    isSettingsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Settings")
                        .font(.caption)
                        .foregroundStyle(Color.paperSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.paperSecondaryText)
                        .rotationEffect(.degrees(isSettingsExpanded ? 0 : -90))
                        .animation(standardSpring, value: isSettingsExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isSettingsExpanded ? "Hide settings" : "Show settings")
            .accessibilityValue(isSettingsExpanded ? "Expanded" : "Collapsed")

            if isSettingsExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Launch on login")
                            .font(.caption)
                            .foregroundStyle(Color.paperSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        PaperToggle(
                            isOn: Binding(
                                get: { launchAtLogin.isEnabled },
                                set: { launchAtLogin.setEnabled($0) }
                            ),
                            label: "Launch on login",
                            status: launchAtLogin.accessibilityStatus,
                            enabledHelp: "Disable launch on login",
                            disabledHelp: "Enable launch on login"
                        )
                    }

                    if launchAtLogin.needsSystemApproval {
                        Button("Open Login Items Settings") {
                            launchAtLogin.openSystemSettings()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }

                    if let errorMessage = launchAtLogin.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Launch on login error: \(errorMessage)")
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }

            PaperDivider()

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
        controller.deviceName ?? "OnePlus Buds"
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

    private var connectionStatusColor: Color {
        switch controller.phase {
        case .ready:
            .green
        case .failed:
            .red
        case .disabled, .waitingForBluetooth:
            Color.paperInactiveIcon
        default:
            Color.paperSelected
        }
    }
}
