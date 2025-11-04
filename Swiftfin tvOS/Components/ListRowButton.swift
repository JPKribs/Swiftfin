//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import SwiftUI

// TODO: on focus, make the cancel and destructive style
//       match style like in an `alert`
struct ListRowButton: View {

    // MARK: - Environment

    @Environment(\.isEnabled)
    private var isEnabled

    // MARK: - Button Variables

    let title: String
    let role: ButtonRole?
    let action: () -> Void

    // MARK: - Initializer

    init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(secondaryStyle)

                Text(title)
                    .foregroundStyle(primaryStyle)
                    .font(.body.weight(.bold))
            }
        }
        .listRowInsets(.zero)
        .frame(maxHeight: 75)
    }

    // MARK: - Primary Style

    private var primaryStyle: some ShapeStyle {
        if role == .destructive || role == .cancel {
            return AnyShapeStyle(Color.red)
        } else {
            return AnyShapeStyle(HierarchicalShapeStyle.primary)
        }
    }

    // MARK: - Secondary Style

    private var secondaryStyle: some ShapeStyle {
        if role == .destructive || role == .cancel {
            return AnyShapeStyle(Color.red.opacity(0.2))
        } else {
            return AnyShapeStyle(HierarchicalShapeStyle.secondary)
        }
    }
}
