//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import SwiftUI

// TODO: should use environment refresh instead?
struct ErrorView<ErrorType: Error>: View {

    @Injected(\.currentUserSession)
    private var userSession

    @Default(.accentColor)
    private var accentColor

    @EnvironmentObject
    private var rootCoordinator: RootCoordinator

    @Router
    private var router

    private let error: ErrorType
    private var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(Color.red)

            Text(error.localizedDescription)
                .frame(minWidth: 50, maxWidth: 240)
                .multilineTextAlignment(.center)

            if let onRetry {
                ListRowButton(L10n.retry) {
                    onRetry()
                }
                .frame(maxWidth: 300)
                .frame(height: 50)
                .foregroundStyle(accentColor.overlayColor, accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if error.localizedDescription.contains("401") || error.localizedDescription.contains("403")// TODO: Is there a way to purely get the code
            {
                ListRowButton(L10n.switchUser, role: .destructive) {
                    UIDevice.impact(.medium)

                    Defaults[.lastSignedInUserID] = .signedOut
                    Container.shared.currentUserSession.reset()
                    Notifications[.didSignOut].post()

                    router.dismiss()
                }
                .frame(maxWidth: 300)
                .frame(maxHeight: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Error is often indicative that the session expired. Please sign into another user or replace your access token to continue.")
                    .frame(minWidth: 50, maxWidth: 240)
                    .multilineTextAlignment(.center)
            }
        }
        .onNotification(.didSignIn) {
            if let onRetry {
                onRetry()
            }
        }
    }
}

extension ErrorView {

    init(error: ErrorType) {
        self.init(
            error: error,
            onRetry: nil
        )
    }

    func onRetry(_ action: @escaping () -> Void) -> Self {
        copy(modifying: \.onRetry, with: action)
    }
}
