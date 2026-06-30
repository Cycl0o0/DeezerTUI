import SwiftUI

extension Color {
    init(hex: UInt32, _ a: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: a)
    }
}

enum DZ {
    static let accent    = Color(hex: 0xA238FF)
    static let accentMag = Color(hex: 0xC01FC3)
    static let windowBG  = Color(hex: 0x14041E)
    static let sidebarBG = Color(hex: 0x130D1C)
    static let panelBG   = Color(hex: 0x1B1226)
    static let selTint   = Color(hex: 0xA238FF, 0.30)
    static let nowTint   = Color(hex: 0xA238FF, 0.16)
    static let textPri   = Color(hex: 0xFFFFF3)
    static let textSec   = Color(hex: 0xA2A2AD)
    static let hairline  = Color.white.opacity(0.08)
}
