//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension Color {

    static let jellyfinPurple = Color(red: 172 / 255, green: 92 / 255, blue: 195 / 255, opacity: 1)

    var uiColor: UIColor {
        UIColor(self)
    }

    var overlayColor: Color {
        Color(uiColor: uiColor.overlayColor)
    }

    // TODO: Correct and add colors
    #if os(tvOS)
    static let systemFill = Color.white
    static let secondarySystemFill = Color.gray
    static let tertiarySystemFill = Color.black
    static let lightGray = Color(UIColor.lightGray)

    #else
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)

    static let systemFill = Color(UIColor.systemFill)
    static let secondarySystemFill = Color(UIColor.secondarySystemFill)
    static let tertiarySystemFill = Color(UIColor.tertiarySystemFill)
    #endif
}

extension Color {

    struct RGBA {

        enum Component {
            case red
            case green
            case blue
            case alpha
        }

        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat
    }

    var rgbaComponents: RGBA {
        get {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            return RGBA(
                red: r,
                green: g,
                blue: b,
                alpha: a
            )
        }
        mutating set {
            self = Color(
                red: newValue.red,
                green: newValue.green,
                blue: newValue.blue,
                opacity: newValue.alpha
            )
        }
    }

    func with(rgba: WritableKeyPath<RGBA, CGFloat>, value: CGFloat) -> Color {
        var components = rgbaComponents
        components[keyPath: rgba] = value
        return Color(
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }

    init(hex: String) {
        let s = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        let x = UInt64(s, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((x >> 16) & 255) / 255,
            green: Double((x >> 8) & 255) / 255,
            blue: Double(x & 255) / 255,
            opacity: s.count > 6 ? Double((x >> 24) & 255) / 255 : 1
        )
    }

    var hexString: String {
        let components = rgbaComponents
        let r = Int(components.red * 255)
        let g = Int(components.green * 255)
        let b = Int(components.blue * 255)
        let a = Int(components.alpha * 255)

        if a < 255 {
            return String(format: "%02X%02X%02X%02X", r, g, b, a)
        } else {
            return String(format: "%02X%02X%02X", r, g, b)
        }
    }
}

extension Color {

    /// Valid color names in CSS
    /// - https://www.w3schools.com/colors/colors_hex.asp
    private enum NamedColor: String {
        case aliceblue
        case antiquewhite
        case aqua
        case aquamarine
        case azure
        case beige
        case bisque
        case black
        case blanchedalmond
        case blue
        case blueviolet
        case brown
        case burlywood
        case cadetblue
        case chartreuse
        case chocolate
        case coral
        case cornflowerblue
        case cornsilk
        case crimson
        case cyan
        case darkblue
        case darkcyan
        case darkgoldenrod
        case darkgray
        case darkgreen
        case darkgrey
        case darkkhaki
        case darkmagenta
        case darkolivegreen
        case darkorange
        case darkorchid
        case darkred
        case darksalmon
        case darkseagreen
        case darkslateblue
        case darkslategray
        case darkslategrey
        case darkturquoise
        case darkviolet
        case deeppink
        case deepskyblue
        case dimgray
        case dimgrey
        case dodgerblue
        case firebrick
        case floralwhite
        case forestgreen
        case fuchsia
        case gainsboro
        case ghostwhite
        case gold
        case goldenrod
        case gray
        case green
        case greenyellow
        case grey
        case honeydew
        case hotpink
        case indianred
        case indigo
        case ivory
        case khaki
        case lavender
        case lavenderblush
        case lawngreen
        case lemonchiffon
        case lightblue
        case lightcoral
        case lightcyan
        case lightgoldenrodyellow
        case lightgray
        case lightgreen
        case lightgrey
        case lightpink
        case lightsalmon
        case lightseagreen
        case lightskyblue
        case lightslategray
        case lightslategrey
        case lightsteelblue
        case lightyellow
        case lime
        case limegreen
        case linen
        case magenta
        case maroon
        case mediumaquamarine
        case mediumblue
        case mediumorchid
        case mediumpurple
        case mediumseagreen
        case mediumslateblue
        case mediumspringgreen
        case mediumturquoise
        case mediumvioletred
        case midnightblue
        case mintcream
        case mistyrose
        case moccasin
        case navajowhite
        case navy
        case oldlace
        case olive
        case olivedrab
        case orange
        case orangered
        case orchid
        case palegoldenrod
        case palegreen
        case paleturquoise
        case palevioletred
        case papayawhip
        case peachpuff
        case peru
        case pink
        case plum
        case powderblue
        case purple
        case rebeccapurple
        case red
        case rosybrown
        case royalblue
        case saddlebrown
        case salmon
        case sandybrown
        case seagreen
        case seashell
        case sienna
        case silver
        case skyblue
        case slateblue
        case slategray
        case slategrey
        case snow
        case springgreen
        case steelblue
        case tan
        case teal
        case thistle
        case tomato
        case turquoise
        case violet
        case wheat
        case white
        case whitesmoke
        case yellow
        case yellowgreen

        var color: Color {
            switch self {
            case .aqua, .cyan:
                .cyan
            case .black:
                .black
            case .blue:
                .blue
            case .gray, .grey:
                .gray
            case .green:
                .green
            case .fuchsia, .magenta:
                .pink
            case .orange:
                .orange
            case .purple:
                .purple
            case .red:
                .red
            case .teal:
                .teal
            case .white:
                .white
            case .yellow:
                .yellow
            /// Color names in HTML that don't have a built-in SwiftUI equivalent
            case .aliceblue:
                .init(hex: "#f0f8ff")
            case .antiquewhite:
                .init(hex: "#faebd7")
            case .aquamarine:
                .init(hex: "#7fffd4")
            case .azure:
                .init(hex: "#f0ffff")
            case .beige:
                .init(hex: "#f5f5dc")
            case .bisque:
                .init(hex: "#ffe4c4")
            case .blanchedalmond:
                .init(hex: "#ffebcd")
            case .blueviolet:
                .init(hex: "#8a2be2")
            case .brown:
                .init(hex: "#a52a2a")
            case .burlywood:
                .init(hex: "#deb887")
            case .cadetblue:
                .init(hex: "#5f9ea0")
            case .chartreuse:
                .init(hex: "#7fff00")
            case .chocolate:
                .init(hex: "#d2691e")
            case .coral:
                .init(hex: "#ff7f50")
            case .cornflowerblue:
                .init(hex: "#6495ed")
            case .cornsilk:
                .init(hex: "#fff8dc")
            case .crimson:
                .init(hex: "#dc143c")
            case .darkblue:
                .init(hex: "#00008b")
            case .darkcyan:
                .init(hex: "#008b8b")
            case .darkgoldenrod:
                .init(hex: "#b8860b")
            case .darkgray, .darkgrey:
                .init(hex: "#a9a9a9")
            case .darkgreen:
                .init(hex: "#006400")
            case .darkkhaki:
                .init(hex: "#bdb76b")
            case .darkmagenta:
                .init(hex: "#8b008b")
            case .darkolivegreen:
                .init(hex: "#556b2f")
            case .darkorange:
                .init(hex: "#ff8c00")
            case .darkorchid:
                .init(hex: "#9932cc")
            case .darkred:
                .init(hex: "#8b0000")
            case .darksalmon:
                .init(hex: "#e9967a")
            case .darkseagreen:
                .init(hex: "#8fbc8f")
            case .darkslateblue:
                .init(hex: "#483d8b")
            case .darkslategray, .darkslategrey:
                .init(hex: "#2f4f4f")
            case .darkturquoise:
                .init(hex: "#00ced1")
            case .darkviolet:
                .init(hex: "#9400d3")
            case .deeppink:
                .init(hex: "#ff1493")
            case .deepskyblue:
                .init(hex: "#00bfff")
            case .dimgray, .dimgrey:
                .init(hex: "#696969")
            case .dodgerblue:
                .init(hex: "#1e90ff")
            case .firebrick:
                .init(hex: "#b22222")
            case .floralwhite:
                .init(hex: "#fffaf0")
            case .forestgreen:
                .init(hex: "#228b22")
            case .gainsboro:
                .init(hex: "#dcdcdc")
            case .ghostwhite:
                .init(hex: "#f8f8ff")
            case .gold:
                .init(hex: "#ffd700")
            case .goldenrod:
                .init(hex: "#daa520")
            case .greenyellow:
                .init(hex: "#adff2f")
            case .honeydew:
                .init(hex: "#f0fff0")
            case .hotpink:
                .init(hex: "#ff69b4")
            case .indianred:
                .init(hex: "#cd5c5c")
            case .indigo:
                .init(hex: "#4b0082")
            case .ivory:
                .init(hex: "#fffff0")
            case .khaki:
                .init(hex: "#f0e68c")
            case .lavender:
                .init(hex: "#e6e6fa")
            case .lavenderblush:
                .init(hex: "#fff0f5")
            case .lawngreen:
                .init(hex: "#7cfc00")
            case .lemonchiffon:
                .init(hex: "#fffacd")
            case .lightblue:
                .init(hex: "#add8e6")
            case .lightcoral:
                .init(hex: "#f08080")
            case .lightcyan:
                .init(hex: "#e0ffff")
            case .lightgoldenrodyellow:
                .init(hex: "#fafad2")
            case .lightgray, .lightgrey:
                .init(hex: "#d3d3d3")
            case .lightgreen:
                .init(hex: "#90ee90")
            case .lightpink:
                .init(hex: "#ffb6c1")
            case .lightsalmon:
                .init(hex: "#ffa07a")
            case .lightseagreen:
                .init(hex: "#20b2aa")
            case .lightskyblue:
                .init(hex: "#87cefa")
            case .lightslategray, .lightslategrey:
                .init(hex: "#778899")
            case .lightsteelblue:
                .init(hex: "#b0c4de")
            case .lightyellow:
                .init(hex: "#ffffe0")
            case .lime:
                .init(hex: "#00ff00")
            case .limegreen:
                .init(hex: "#32cd32")
            case .linen:
                .init(hex: "#faf0e6")
            case .maroon:
                .init(hex: "#800000")
            case .mediumaquamarine:
                .init(hex: "#66cdaa")
            case .mediumblue:
                .init(hex: "#0000cd")
            case .mediumorchid:
                .init(hex: "#ba55d3")
            case .mediumpurple:
                .init(hex: "#9370db")
            case .mediumseagreen:
                .init(hex: "#3cb371")
            case .mediumslateblue:
                .init(hex: "#7b68ee")
            case .mediumspringgreen:
                .init(hex: "#00fa9a")
            case .mediumturquoise:
                .init(hex: "#48d1cc")
            case .mediumvioletred:
                .init(hex: "#c71585")
            case .midnightblue:
                .init(hex: "#191970")
            case .mintcream:
                .init(hex: "#f5fffa")
            case .mistyrose:
                .init(hex: "#ffe4e1")
            case .moccasin:
                .init(hex: "#ffe4b5")
            case .navajowhite:
                .init(hex: "#ffdead")
            case .navy:
                .init(hex: "#000080")
            case .oldlace:
                .init(hex: "#fdf5e6")
            case .olive:
                .init(hex: "#808000")
            case .olivedrab:
                .init(hex: "#6b8e23")
            case .orangered:
                .init(hex: "#ff4500")
            case .orchid:
                .init(hex: "#da70d6")
            case .palegoldenrod:
                .init(hex: "#eee8aa")
            case .palegreen:
                .init(hex: "#98fb98")
            case .paleturquoise:
                .init(hex: "#afeeee")
            case .palevioletred:
                .init(hex: "#db7093")
            case .papayawhip:
                .init(hex: "#ffefd5")
            case .peachpuff:
                .init(hex: "#ffdab9")
            case .peru:
                .init(hex: "#cd853f")
            case .pink:
                .init(hex: "#ffc0cb")
            case .plum:
                .init(hex: "#dda0dd")
            case .powderblue:
                .init(hex: "#b0e0e6")
            case .rebeccapurple:
                .init(hex: "#663399")
            case .rosybrown:
                .init(hex: "#bc8f8f")
            case .royalblue:
                .init(hex: "#4169e1")
            case .saddlebrown:
                .init(hex: "#8b4513")
            case .salmon:
                .init(hex: "#fa8072")
            case .sandybrown:
                .init(hex: "#f4a460")
            case .seagreen:
                .init(hex: "#2e8b57")
            case .seashell:
                .init(hex: "#fff5ee")
            case .sienna:
                .init(hex: "#a0522d")
            case .silver:
                .init(hex: "#c0c0c0")
            case .skyblue:
                .init(hex: "#87ceeb")
            case .slateblue:
                .init(hex: "#6a5acd")
            case .slategray, .slategrey:
                .init(hex: "#708090")
            case .snow:
                .init(hex: "#fffafa")
            case .springgreen:
                .init(hex: "#00ff7f")
            case .steelblue:
                .init(hex: "#4682b4")
            case .tan:
                .init(hex: "#d2b48c")
            case .thistle:
                .init(hex: "#d8bfd8")
            case .tomato:
                .init(hex: "#ff6347")
            case .turquoise:
                .init(hex: "#40e0d0")
            case .violet:
                .init(hex: "#ee82ee")
            case .wheat:
                .init(hex: "#f5deb3")
            case .whitesmoke:
                .init(hex: "#f5f5f5")
            case .yellowgreen:
                .init(hex: "#9acd32")
            }
        }
    }

    /// Initialize a color by a *known* color name
    init?(name: String) {
        let value = name
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        guard let named = NamedColor(rawValue: value) else { return nil }

        self = named.color
    }

    /// A named, `rgb()`, or hex color from HTML or CSS
    init?(html: String, supportsOpacity: Bool = false) {
        let value = html
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        if let named = Color(name: value) {
            self = named
        } else if value.hasPrefix("rgb") {
            let channels = value.split { !$0.isNumber && $0 != Character(.decimal) }
                .prefix(4)
                .compactMap { Double($0) }

            guard channels.count == 3 || channels.count == 4 else { return nil }

            self.init(
                red: channels[0] / 255,
                green: channels[1] / 255,
                blue: channels[2] / 255,
                opacity: supportsOpacity && channels.count == 4 ? channels[3] : 1
            )
        } else {
            guard value.hasPrefix("#") else { return nil }

            let digits = value.dropFirst()
            let hex = digits.count == 3 ? digits.map { "\($0)\($0)" }.joined() : String(digits)

            guard hex.count >= 6, UInt32(hex.prefix(6), radix: 16) != nil else { return nil }

            self.init(hex: String(hex.prefix(6)))
        }
    }
}
