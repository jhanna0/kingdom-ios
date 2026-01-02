import SwiftUI

// MARK: - Kingdom App Theme
// Centralized design system for medieval aesthetics

struct KingdomTheme {
    
    // MARK: - Colors
    struct Colors {
        
        // MARK: Parchment Backgrounds
        /// Main parchment background - used for primary surfaces
        static let parchment = Color(red: 0.95, green: 0.87, blue: 0.70)
        /// Lighter parchment - used for cards and elevated surfaces
        static let parchmentLight = Color(red: 0.98, green: 0.92, blue: 0.80)
        /// Slightly darker parchment - used for secondary cards
        static let parchmentDark = Color(red: 0.92, green: 0.82, blue: 0.65)
        /// Rich parchment - used for emphasis backgrounds
        static let parchmentRich = Color(red: 0.90, green: 0.80, blue: 0.60)
        /// Subtle highlight parchment
        static let parchmentHighlight = Color(red: 0.95, green: 0.9, blue: 0.75)
        /// Neutral parchment for de-emphasized areas
        static let parchmentMuted = Color(red: 0.9, green: 0.85, blue: 0.7)
        
        // MARK: Text Colors (Ink)
        /// Primary text - dark brown ink
        static let inkDark = Color(red: 0.2, green: 0.1, blue: 0.05)
        /// Secondary text - medium brown ink
        static let inkMedium = Color(red: 0.4, green: 0.2, blue: 0.1)
        /// Tertiary text - muted brown ink
        static let inkLight = Color(red: 0.5, green: 0.3, blue: 0.15)
        /// Caption/subtle text
        static let inkSubtle = Color(red: 0.5, green: 0.3, blue: 0.1)
        
        // MARK: Accent Colors
        /// Gold - for crowns, wealth, important elements
        static let gold = Color(red: 0.6, green: 0.4, blue: 0.1)
        /// Lighter gold - for icons and accents
        static let goldLight = Color(red: 0.7, green: 0.5, blue: 0.2)
        /// Warm gold - for building/icon tints
        static let goldWarm = Color(red: 0.6, green: 0.4, blue: 0.2)
        
        // MARK: Button Colors
        /// Primary brown - main action buttons
        static let buttonPrimary = Color(red: 0.5, green: 0.3, blue: 0.1)
        /// Secondary brown - secondary actions
        static let buttonSecondary = Color(red: 0.4, green: 0.25, blue: 0.15)
        /// Success green - check-in, alliance, positive actions
        static let buttonSuccess = Color(red: 0.2, green: 0.5, blue: 0.3)
        /// Danger red - war, destructive actions
        static let buttonDanger = Color(red: 0.7, green: 0.15, blue: 0.1)
        /// Warning orange - alerts, warnings
        static let buttonWarning = Color(red: 0.7, green: 0.3, blue: 0.1)
        /// Special purple - coup, special actions
        static let buttonSpecial = Color(red: 0.3, green: 0.15, blue: 0.4)
        
        // MARK: Border Colors
        /// Standard card/element border
        static let border = Color(red: 0.4, green: 0.3, blue: 0.2)
        /// Darker border for emphasis
        static let borderDark = Color(red: 0.3, green: 0.2, blue: 0.1)
        /// Divider line color
        static let divider = Color(red: 0.4, green: 0.3, blue: 0.2)
        
        // MARK: Semantic Colors
        /// Loading indicator tint
        static let loadingTint = Color(red: 0.5, green: 0.3, blue: 0.1)
        /// Error/alert color
        static let error = Color(red: 0.7, green: 0.3, blue: 0.1)
        /// Disabled/muted state - darker brown for better contrast on parchment
        static let disabled = Color(red: 0.5, green: 0.4, blue: 0.3)
        /// Muted text for de-emphasized content
        static let textMuted = Color(red: 0.45, green: 0.35, blue: 0.25)
        
        // MARK: Kingdom Territory Colors (Map Polygons & Markers)
        /// Player's kingdom - ROYAL BLUE (darker)
        static let territoryPlayer = Color(red: 0.15, green: 0.25, blue: 0.65)
        /// Enemy kingdom - deep muted red (medieval vermillion)
        static let territoryEnemy = Color(red: 0.75, green: 0.30, blue: 0.25)
        /// Allied kingdom - map blue-green (like cartographer's seas)
        static let territoryAllied = Color(red: 0.35, green: 0.60, blue: 0.65)
        
        // Neutral kingdom colors (hash-based assignment)
        static let territoryNeutral0 = Color(red: 0.40, green: 0.55, blue: 0.75)  // Ocean blue
        static let territoryNeutral1 = Color(red: 0.45, green: 0.68, blue: 0.50)  // Forest green
        static let territoryNeutral2 = Color(red: 0.70, green: 0.52, blue: 0.42)  // Terracotta
        static let territoryNeutral3 = Color(red: 0.38, green: 0.65, blue: 0.70)  // Teal
        static let territoryNeutral4 = Color(red: 0.55, green: 0.60, blue: 0.45)  // Sage green
        static let territoryNeutral5 = Color(red: 0.50, green: 0.45, blue: 0.65)  // Dusty purple
        static let territoryNeutral6 = Color(red: 0.65, green: 0.58, blue: 0.45)  // Sandy brown
        static let territoryNeutral7 = Color(red: 0.42, green: 0.58, blue: 0.60)  // Steel blue
        static let territoryNeutral8 = Color(red: 0.58, green: 0.65, blue: 0.42)  // Olive green
        static let territoryNeutral9 = Color(red: 0.68, green: 0.50, blue: 0.52)  // Dusty rose
        static let territoryNeutral10 = Color(red: 0.45, green: 0.52, blue: 0.58) // Slate blue
        static let territoryNeutral11 = Color(red: 0.62, green: 0.55, blue: 0.48) // Warm gray
        
        /// Get territory color for a kingdom based on relationship and hash
        static func territoryColor(kingdomId: String, isPlayer: Bool, isEnemy: Bool, isAllied: Bool) -> Color {
            if isPlayer {
                return territoryPlayer
            } else if isEnemy {
                return territoryEnemy
            } else if isAllied {
                return territoryAllied
            } else {
                // Neutral - hash-based color assignment
                let hash = abs(kingdomId.hashValue)
                let colorIndex = hash % 12
                
                switch colorIndex {
                case 0: return territoryNeutral0
                case 1: return territoryNeutral1
                case 2: return territoryNeutral2
                case 3: return territoryNeutral3
                case 4: return territoryNeutral4
                case 5: return territoryNeutral5
                case 6: return territoryNeutral6
                case 7: return territoryNeutral7
                case 8: return territoryNeutral8
                case 9: return territoryNeutral9
                case 10: return territoryNeutral10
                case 11: return territoryNeutral11
                default: return Color(red: 0.50, green: 0.50, blue: 0.50) // Fallback gray
                }
            }
        }
    }
    
    // MARK: - Typography
    struct Typography {
        static let serifDesign: Font.Design = .serif
        
        static func largeTitle() -> Font {
            .system(.largeTitle, design: serifDesign)
        }
        
        static func title() -> Font {
            .system(.title, design: serifDesign)
        }
        
        static func title2() -> Font {
            .system(.title2, design: serifDesign)
        }
        
        static func title3() -> Font {
            .system(.title3, design: serifDesign)
        }
        
        static func headline() -> Font {
            .system(.headline, design: serifDesign)
        }
        
        static func subheadline() -> Font {
            .system(.subheadline, design: serifDesign)
        }
        
        static func body() -> Font {
            .system(.body, design: serifDesign)
        }
        
        static func caption() -> Font {
            .system(.caption, design: serifDesign)
        }
        
        static func caption2() -> Font {
            .system(.caption2, design: serifDesign)
        }
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let card = (color: Color.black.opacity(0.3), radius: 5.0, x: 2.0, y: 3.0)
        static let cardStrong = (color: Color.black.opacity(0.4), radius: 8.0, x: 2.0, y: 4.0)
        static let button = (color: Color.black.opacity(0.3), radius: 3.0, x: 1.0, y: 2.0)
        static let overlay = (color: Color.black.opacity(0.4), radius: 10.0, x: 0.0, y: 0.0)
        
        // Neo-brutalist offset shadow (solid black offset + soft shadow)
        static let brutalistOffset: CGFloat = 4.0
        static let brutalistSoft = (color: Color.black.opacity(0.15), radius: 12.0, x: 6.0, y: 8.0)
    }
    
    // MARK: - Brutalist Style Constants
    /// Neo-brutalist style inspired by modern bold UI
    struct Brutalist {
        static let borderWidth: CGFloat = 3
        static let borderColor = Color.black
        static let cornerRadiusLarge: CGFloat = 24
        static let cornerRadiusMedium: CGFloat = 16
        static let cornerRadiusSmall: CGFloat = 12
        static let offsetShadow: CGFloat = 4
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let small: CGFloat = 6
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 24
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let large: CGFloat = 8
        static let xLarge: CGFloat = 10
        static let xxLarge: CGFloat = 12
    }
    
    // MARK: - Border Width
    struct BorderWidth {
        static let thin: CGFloat = 1
        static let regular: CGFloat = 2
        static let thick: CGFloat = 3
    }
}

// MARK: - View Modifiers

/// Brutalist badge/pill style with offset shadow
struct BrutalistBadgeStyle: ViewModifier {
    var backgroundColor: Color
    var cornerRadius: CGFloat = 8
    var shadowOffset: CGFloat = 2
    var borderWidth: CGFloat = 2
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.black)
                        .offset(x: shadowOffset, y: shadowOffset)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.black, lineWidth: borderWidth)
                        )
                }
            )
    }
}

/// Brutalist progress bar style with black border
struct BrutalistProgressBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .stroke(Color.black, lineWidth: 2)
            )
    }
}

/// Parchment card style with border and shadow
struct ParchmentCardStyle: ViewModifier {
    var backgroundColor: Color = KingdomTheme.Colors.parchment
    var borderColor: Color = KingdomTheme.Colors.border
    var borderWidth: CGFloat = KingdomTheme.BorderWidth.regular
    var cornerRadius: CGFloat = KingdomTheme.CornerRadius.large
    var hasShadow: Bool = true
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: hasShadow ? KingdomTheme.Shadows.card.color : .clear,
                radius: hasShadow ? KingdomTheme.Shadows.card.radius : 0,
                x: hasShadow ? KingdomTheme.Shadows.card.x : 0,
                y: hasShadow ? KingdomTheme.Shadows.card.y : 0
            )
    }
}

/// Neo-brutalist card style with thick border and offset shadow
struct BrutalistCardStyle: ViewModifier {
    var backgroundColor: Color = KingdomTheme.Colors.parchment
    var borderColor: Color = KingdomTheme.Brutalist.borderColor
    var cornerRadius: CGFloat = KingdomTheme.Brutalist.cornerRadiusMedium
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Offset solid shadow (the distinctive "3D" effect)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(borderColor)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    
                    // Main card background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(borderColor, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                }
            )
            // Soft shadow for depth
            .shadow(
                color: KingdomTheme.Shadows.brutalistSoft.color,
                radius: KingdomTheme.Shadows.brutalistSoft.radius,
                x: KingdomTheme.Shadows.brutalistSoft.x,
                y: KingdomTheme.Shadows.brutalistSoft.y
            )
    }
}

/// Brutalist button style - bold with offset shadow
struct BrutalistButtonStyle: ButtonStyle {
    var backgroundColor: Color = KingdomTheme.Colors.buttonPrimary
    var foregroundColor: Color = .white
    var fullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(foregroundColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // Offset shadow
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                        .fill(Color.black)
                        .offset(x: 3, y: 3)
                    
                    // Button background
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                        .fill(configuration.isPressed ? backgroundColor.opacity(0.8) : backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                .stroke(Color.black, lineWidth: 2)
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
    }
}

/// Medieval button style
struct MedievalButtonStyle: ButtonStyle {
    var color: Color = KingdomTheme.Colors.buttonPrimary
    var fullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KingdomTheme.Typography.subheadline())
            .fontWeight(.semibold)
            .foregroundColor(KingdomTheme.Colors.parchment)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
            .background(configuration.isPressed ? color.opacity(0.8) : color)
            .cornerRadius(KingdomTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.medium)
                    .stroke(color.opacity(0.5), lineWidth: KingdomTheme.BorderWidth.regular)
            )
            .shadow(
                color: KingdomTheme.Shadows.button.color,
                radius: KingdomTheme.Shadows.button.radius,
                x: KingdomTheme.Shadows.button.x,
                y: KingdomTheme.Shadows.button.y
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

/// Medieval button style without shadow - for use inside cards
struct MedievalSubtleButtonStyle: ButtonStyle {
    var color: Color = KingdomTheme.Colors.buttonPrimary
    var fullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KingdomTheme.Typography.subheadline())
            .fontWeight(.semibold)
            .foregroundColor(KingdomTheme.Colors.parchment)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
            .background(configuration.isPressed ? color.opacity(0.8) : color)
            .cornerRadius(KingdomTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.medium)
                    .stroke(color.opacity(0.5), lineWidth: KingdomTheme.BorderWidth.regular)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

/// Toolbar/Navigation button style - clean text style for navigation bars
struct ToolbarButtonStyle: ButtonStyle {
    var color: Color = KingdomTheme.Colors.buttonPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KingdomTheme.Typography.headline())
            .fontWeight(.semibold)
            .foregroundColor(configuration.isPressed ? color.opacity(0.6) : color)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply parchment card styling
    func parchmentCard(
        backgroundColor: Color = KingdomTheme.Colors.parchment,
        borderColor: Color = KingdomTheme.Colors.border,
        borderWidth: CGFloat = KingdomTheme.BorderWidth.regular,
        cornerRadius: CGFloat = KingdomTheme.CornerRadius.large,
        hasShadow: Bool = true
    ) -> some View {
        modifier(ParchmentCardStyle(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            borderWidth: borderWidth,
            cornerRadius: cornerRadius,
            hasShadow: hasShadow
        ))
    }
    
    /// Apply neo-brutalist card styling with thick border and offset shadow
    func brutalistCard(
        backgroundColor: Color = KingdomTheme.Colors.parchment,
        borderColor: Color = KingdomTheme.Brutalist.borderColor,
        cornerRadius: CGFloat = KingdomTheme.Brutalist.cornerRadiusMedium
    ) -> some View {
        modifier(BrutalistCardStyle(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            cornerRadius: cornerRadius
        ))
    }
    
    /// Apply brutalist badge/pill styling with offset shadow
    func brutalistBadge(
        backgroundColor: Color,
        cornerRadius: CGFloat = 8,
        shadowOffset: CGFloat = 2,
        borderWidth: CGFloat = 2
    ) -> some View {
        modifier(BrutalistBadgeStyle(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadowOffset: shadowOffset,
            borderWidth: borderWidth
        ))
    }
    
    /// Apply brutalist progress bar styling
    func brutalistProgressBar() -> some View {
        modifier(BrutalistProgressBarStyle())
    }
    
    /// Apply parchment background for full screens
    func parchmentBackground() -> some View {
        self.background(KingdomTheme.Colors.parchment.ignoresSafeArea())
    }
    
    /// Apply parchment theming to navigation bar
    func parchmentNavigationBar() -> some View {
        self
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - Convenience Button Styles

extension ButtonStyle where Self == MedievalButtonStyle {
    static var medieval: MedievalButtonStyle { MedievalButtonStyle() }
    static var medievalFullWidth: MedievalButtonStyle { MedievalButtonStyle(fullWidth: true) }
    
    static func medieval(color: Color, fullWidth: Bool = false) -> MedievalButtonStyle {
        MedievalButtonStyle(color: color, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == MedievalSubtleButtonStyle {
    static var medievalSubtle: MedievalSubtleButtonStyle { MedievalSubtleButtonStyle() }
    static var medievalSubtleFullWidth: MedievalSubtleButtonStyle { MedievalSubtleButtonStyle(fullWidth: true) }
    
    static func medievalSubtle(color: Color, fullWidth: Bool = false) -> MedievalSubtleButtonStyle {
        MedievalSubtleButtonStyle(color: color, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == ToolbarButtonStyle {
    static var toolbar: ToolbarButtonStyle { ToolbarButtonStyle() }
    
    static func toolbar(color: Color) -> ToolbarButtonStyle {
        ToolbarButtonStyle(color: color)
    }
}

extension ButtonStyle where Self == BrutalistButtonStyle {
    static var brutalist: BrutalistButtonStyle { BrutalistButtonStyle() }
    static var brutalistFullWidth: BrutalistButtonStyle { BrutalistButtonStyle(fullWidth: true) }
    
    static func brutalist(backgroundColor: Color, foregroundColor: Color = .white, fullWidth: Bool = false) -> BrutalistButtonStyle {
        BrutalistButtonStyle(backgroundColor: backgroundColor, foregroundColor: foregroundColor, fullWidth: fullWidth)
    }
}

