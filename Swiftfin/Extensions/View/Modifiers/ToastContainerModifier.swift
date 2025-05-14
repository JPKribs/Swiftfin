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

    // MARK: - Toast Manager

    @Injected(\.toastManager)
    private var toastManager

    // MARK: - Observable Toast Manager

    @ObservedObject
    private var observableManager: ToastManager

    init() {
        self.observableManager = Container.shared.toastManager()
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                content

                VStack(spacing: 8) {
                    ForEach(observableManager.messages.filter { !$0.isRead }) { toast in
                        ToastNotificationView(toast: toast) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                toastManager.markAsRead(toast.id)
                                toastManager.dismiss(toast.id)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: geometry.size.width)
            }
        }
        .animation(.easeInOut, value: observableManager.messages.count)
    }
}
