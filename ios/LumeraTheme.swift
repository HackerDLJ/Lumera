import SwiftUI

extension Color {
    static let lumeraBackground = Color(light: Color(red: 0.965, green: 0.976, blue: 0.969), dark: Color(red: 0.055, green: 0.075, blue: 0.068))
    static let lumeraSurface = Color(light: .white, dark: Color(red: 0.095, green: 0.12, blue: 0.108))
    static let lumeraPrimary = Color(light: Color(red: 0.10, green: 0.27, blue: 0.23), dark: Color(red: 0.36, green: 0.72, blue: 0.61))
    static let lumeraText = Color(light: Color(red: 0.09, green: 0.13, blue: 0.11), dark: Color(red: 0.93, green: 0.96, blue: 0.94))
    static let lumeraSecondaryText = Color(light: Color(red: 0.38, green: 0.43, blue: 0.40), dark: Color(red: 0.68, green: 0.73, blue: 0.70))
    static let lumeraBorder = Color(light: Color(red: 0.88, green: 0.91, blue: 0.89), dark: Color(red: 0.18, green: 0.22, blue: 0.20))

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

struct LumeraCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.lumeraSurface)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.lumeraBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

extension View {
    func lumeraCard() -> some View { modifier(LumeraCard()) }
}
