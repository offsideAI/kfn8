import SwiftUI

/// Showroom palette: bone/paper, walnut/clay, brass (active state), ink (text). No purple, indigo or cyan anywhere.
enum Showroom {
    static let bone = Color(red: 0.937, green: 0.914, blue: 0.867)
    static let paper = Color(red: 0.969, green: 0.953, blue: 0.922)
    static let walnut = Color(red: 0.306, green: 0.212, blue: 0.153)
    static let clay = Color(red: 0.690, green: 0.502, blue: 0.408)
    static let brass = Color(red: 0.722, green: 0.573, blue: 0.290)
    static let ink = Color(red: 0.110, green: 0.102, blue: 0.094)
    /// Quiet status text: ink at reduced opacity, never red.
    static let quiet = Color(red: 0.110, green: 0.102, blue: 0.094).opacity(0.7)

    /// Fraunces for display, Hanken Grotesk for UI. Both scale with Dynamic Type via `relativeTo`.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Fraunces", size: size, relativeTo: style)
    }
    static func ui(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Hanken Grotesk", size: size, relativeTo: style)
    }
}

struct BrassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Showroom.ui(17, relativeTo: .headline))
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Showroom.brass.opacity(configuration.isPressed ? 0.75 : 1), in: .capsule)
            .foregroundStyle(Showroom.ink)
    }
}
