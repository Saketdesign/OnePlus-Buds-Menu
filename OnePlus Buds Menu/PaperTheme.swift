import AppKit
import SwiftUI

extension Color {
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

extension ShapeStyle where Self == LinearGradient {
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

extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
