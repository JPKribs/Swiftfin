//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension InsetFilterBar {

    struct InsetFilterBarButton: View {

        @Default(.accentColor)
        private var accentColor

        @Environment(\.buttonDimension)
        private var dimension
        @Environment(\.isHighlighted)
        private var isSelected

        @FocusState
        private var isFocused: Bool

        private let title: String
        private let systemImage: String
        private let edge: HorizontalEdge
        private let role: ButtonRole?
        private let action: () -> Void

        init(
            _ title: String,
            systemImage: String,
            edge: HorizontalEdge,
            role: ButtonRole? = nil,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.edge = edge
            self.role = role
            self.action = action
        }

        private var foregroundStyle: Color {
            if isFocused {
                if role == .destructive {
                    .red.overlayColor
                } else {
                    .primary.overlayColor
                }
            } else if isSelected {
                accentColor.overlayColor
            } else {
                .primary
            }
        }

//        @available(tvOS 26.0, *)
//        private var glassEffect: Glass {
//            switch (isFocused, isSelected, role) {
//            case (true, _, .destructive):
//                .regular.tint(.red).interactive()
//
//            case (true, true, _):
//                .regular.tint(accentColor)
//
//            case (true, false, _):
//                .regular.interactive()
//
//            case (false, true, _):
//                .regular.tint(accentColor)
//
//            case (false, false, _):
//                .regular
//            }
//        }

//        @available(tvOS 26.0, *)
//        private var glassForegroundStyle: Color {
//            if role == .destructive {
//                .red.overlayColor
//            } else {
//                .primary
//            }
//        }

        private var backgroundStyle: Color {
            if isFocused && role == .destructive {
                .red
            } else if isSelected {
                accentColor
            } else {
                .primary
            }
        }

        @ViewBuilder
        private func buttonLabel(foreground: Color) -> some View {
            HStack(spacing: 0) {
                if edge == .trailing, isFocused {
                    Text(title)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 24)
                        .transition(.move(edge: edge == .leading ? .leading : .trailing).combined(with: .opacity))
                }

                Image(systemName: systemImage)
                    .frame(width: dimension, height: dimension)

                if edge == .leading, isFocused {
                    Text(title)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 24)
                        .transition(.move(edge: edge == .leading ? .leading : .trailing).combined(with: .opacity))
                }
            }
            .foregroundStyle(foreground)
        }

        var body: some View {
            Button {
                action()
            } label: {
                Group {
//                    if #available(tvOS 26.0, *) {
//                        buttonLabel(foreground: glassForegroundStyle)
//                            .glassEffect(glassEffect, in: .capsule)
//                    } else {
                    buttonLabel(foreground: foregroundStyle)
                        .background {
                            Capsule()
                                .foregroundStyle(backgroundStyle)
                                .shadow(radius: (isFocused || isSelected) ? 4 : 0, y: (isFocused || isSelected) ? 2 : 0)
                        }
//                    }
                }
            }
            .buttonStyle(.borderless)
            .hoverEffectDisabled()
            .focusEffectDisabled()
            .focused($isFocused)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}
