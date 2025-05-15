//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Factory
import Foundation
import SwiftUI

struct ToastContainerModifier: ViewModifier {

    // MARK: - Observable Toast Manager

    @ObservedObject
    private var toastManager: ToastManager

    init() {
        self.toastManager = Container.shared.toastManager()
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .overlay(
                toastOverlay,
                alignment: .bottom
            )
    }

    // MARK: - Toast Overlay

    private var toastOverlay: some View {
        VStack(spacing: 8) {
            ForEach(toastManager.messages.filter { !$0.isRead }) { toast in
                ToastMessage(toast: toast) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        toastManager.markAsRead(toast.id)
                        toastManager.dismiss(toast.id)
                    }
                }
            }
        }
    }
}
