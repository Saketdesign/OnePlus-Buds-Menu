import SwiftUI

struct PaperToggle: View {
    @Binding var isOn: Bool
    let label: String
    let status: String
    let enabledHelp: String
    let disabledHelp: String

    var body: some View {
        Toggle(label, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(PaperToggleStyle())
            .help(isOn ? enabledHelp : disabledHelp)
            .accessibilityLabel(label)
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

struct PaperDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.paperDivider)
            .frame(height: 1)
    }
}

struct NoiseControlOptionButton: View {
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
                    .foregroundStyle(
                        (isSelected || isLoading) ? .paperSelectedTextGradient : .paperSecondaryTextGradient
                    )
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

enum BatteryMetric {
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

struct BatteryMetricView: View {
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

                Text(percentage.map { "\($0)%" } ?? "-")
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
