import SwiftUI

// MARK: - Font Styles
// Centralized typography system with bold, readable fonts for the game

struct FontStyles {
    
    // MARK: - Display Fonts (Extra Large)
    /// Extra large display text - 32pt, bold, serif
    static let displayLarge = Font.system(size: 32, weight: .bold, design: .serif)
    
    /// Medium display text - 28pt, bold, serif
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .serif)
    
    /// Small display text - 24pt, bold, serif
    static let displaySmall = Font.system(size: 24, weight: .bold, design: .serif)
    
    // MARK: - Headings
    /// Main section heading - 22pt, bold, serif
    static let headingLarge = Font.system(size: 22, weight: .bold, design: .serif)
    
    /// Card/component heading - 18pt, bold, serif
    static let headingMedium = Font.system(size: 18, weight: .bold, design: .serif)
    
    /// Small heading - 16pt, bold, serif
    static let headingSmall = Font.system(size: 16, weight: .bold, design: .serif)
    
    // MARK: - Body Text
    /// Large body text - 17pt, bold (for emphasis)
    static let bodyLargeBold = Font.system(size: 17, weight: .bold)
    
    /// Large body text - 17pt, medium
    static let bodyLarge = Font.system(size: 17, weight: .medium)
    
    /// Standard body text - 16pt, medium
    static let bodyMedium = Font.system(size: 16, weight: .medium)
    
    /// Standard body text - 16pt, semibold
    static let bodyMediumBold = Font.system(size: 16, weight: .semibold)
    
    /// Small body text - 15pt, medium
    static let bodySmall = Font.system(size: 15, weight: .medium)
    
    /// Small body text - 15pt, semibold
    static let bodySmallBold = Font.system(size: 15, weight: .semibold)
    
    // MARK: - Labels & Metadata
    /// Standard label - 14pt, semibold
    static let labelLarge = Font.system(size: 14, weight: .semibold)
    
    /// Standard label - 14pt, medium
    static let labelMedium = Font.system(size: 14, weight: .medium)
    
    /// Standard label - 14pt, bold
    static let labelBold = Font.system(size: 14, weight: .bold)
    
    /// Small label - 13pt, semibold
    static let labelSmall = Font.system(size: 13, weight: .semibold)
    
    /// Tiny label - 12pt, semibold
    static let labelTiny = Font.system(size: 12, weight: .semibold)
    
    /// Extra tiny label - 11pt, bold (for badges)
    static let labelBadge = Font.system(size: 11, weight: .bold)
    
    // MARK: - Captions (Very Small Text)
    /// Caption large - 10pt, medium
    static let captionLarge = Font.system(size: 10, weight: .medium)
    
    /// Caption medium - 9pt, bold, serif (for card headers)
    static let captionMedium = Font.system(size: 9, weight: .bold, design: .serif)
    
    /// Caption small - 8pt, black (for tiny labels)
    static let captionSmall = Font.system(size: 8, weight: .black)
    
    // MARK: - Stats (Monospaced for Numbers)
    /// Stat large - 18pt, black, monospaced
    static let statLarge = Font.system(size: 18, weight: .black, design: .monospaced)
    
    /// Stat medium - 14pt, black, monospaced
    static let statMedium = Font.system(size: 14, weight: .black, design: .monospaced)
    
    /// Stat small - 10pt, black, monospaced
    static let statSmall = Font.system(size: 10, weight: .black, design: .monospaced)
    
    /// Stat tiny - 9pt, bold, monospaced
    static let statTiny = Font.system(size: 9, weight: .bold, design: .monospaced)
    
    // MARK: - Black Weight Variants (For Emphasis)
    /// Title black - 16pt, black
    static let titleBlack = Font.system(size: 16, weight: .black)
    
    /// Label black - 14pt, black, serif
    static let labelBlackSerif = Font.system(size: 14, weight: .black, design: .serif)
    
    /// Label black small - 13pt, black, serif
    static let labelBlackSmall = Font.system(size: 13, weight: .black, design: .serif)
    
    /// Label black tiny - 12pt, black, serif
    static let labelBlackTiny = Font.system(size: 12, weight: .black, design: .serif)
    
    /// Label black mini - 11pt, black, serif
    static let labelBlackMini = Font.system(size: 11, weight: .black, design: .serif)
    
    /// Label black nano - 10pt, black, serif
    static let labelBlackNano = Font.system(size: 10, weight: .black, design: .serif)
    
    // MARK: - Giant Display (For Big Numbers/Results)
    /// Giant display - 60pt, bold
    static let displayGiant = Font.system(size: 60, weight: .bold)
    
    /// Display extra large - 50pt, black
    static let displayExtraLarge = Font.system(size: 50, weight: .black)
    
    /// Display huge - 40pt
    static let displayHuge = Font.system(size: 40)
    
    /// Result large - 36pt, black
    static let resultLarge = Font.system(size: 36, weight: .black)
    
    /// Result medium - 32pt, black
    static let resultMedium = Font.system(size: 32, weight: .black)
    
    /// Result small - 24pt, black, serif
    static let resultSmall = Font.system(size: 24, weight: .black, design: .serif)
    
    /// Result tiny - 20pt, bold
    static let resultTiny = Font.system(size: 20, weight: .bold)
    
    // MARK: - Icons
    /// Large icon - 28pt, bold
    static let iconExtraLarge = Font.system(size: 28, weight: .bold)
    
    /// Large icon - 26pt, bold
    static let iconLarge = Font.system(size: 26, weight: .bold)
    
    /// Medium icon - 22pt, bold
    static let iconMedium = Font.system(size: 22, weight: .bold)
    
    /// Small icon - 18pt, bold
    static let iconSmall = Font.system(size: 18, weight: .bold)
    
    /// Tiny icon - 14pt, bold
    static let iconTiny = Font.system(size: 14, weight: .bold)
    
    /// Mini icon - 12pt, bold (for inline icons)
    static let iconMini = Font.system(size: 12, weight: .bold)
}

// MARK: - View Extension for Easy Access
extension View {
    /// Apply a font style with optional color
    func fontStyle(_ style: Font, color: Color? = nil) -> some View {
        self
            .font(style)
            .foregroundColor(color)
    }
}

