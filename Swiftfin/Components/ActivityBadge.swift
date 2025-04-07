//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct ActivityBadge: View {

    // MARK: - Displayed Value

    let value: Int

    // MARK: - Badge Coordinate

    private let x = 12.0
    private let y = 2.0
    private let padding = 8.0

    // MARK: - Font Dimensions

    private var size: CGFloat {
        UIFont
            .preferredFont(forTextStyle: .caption1)
            .pointSize
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.accentColor)
                .frame(width: size * widthMultplier + padding, height: size + padding, alignment: .topTrailing)
                .overlay {
                    Capsule()
                        .stroke(Color.systemBackground, lineWidth: 1.5)
                }
                .position(x: x, y: y)

            badgeText
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor.overlayColor)
                .position(x: x, y: y)
        }
        .opacity(value == 0 ? 0 : 1)
    }

    // MARK: - Get the Value as Text

    private var badgeText: Text {
        if value < 100 {
            Text(value.description)
        } else {
            Text("99+")
        }
    }

    // MARK: - Get Badge Width

    private var widthMultplier: Double {
        if value < 10 {
            return 1.0
        } else if value < 100 {
            return 1.5
        } else {
            return 2.0
        }
    }
}
