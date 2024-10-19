//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension UserAdminDetailView.UserAdminPermissionsView {
    struct MediaPlaybackSection: View {
        @Binding
        var tempPolicy: UserPolicy

        @Environment(\.isEnabled)
        var isEnabled

        var body: some View {
            Section("Media playback") {
                Toggle("Allow media playback", isOn: Binding(
                    get: { tempPolicy.enableMediaPlayback ?? false },
                    set: { tempPolicy.enableMediaPlayback = $0 }
                ))
                .disabled(!isEnabled)

                Toggle("Allow audio transcoding", isOn: Binding(
                    get: { tempPolicy.enableAudioPlaybackTranscoding ?? false },
                    set: { tempPolicy.enableAudioPlaybackTranscoding = $0 }
                ))
                .disabled(!isEnabled)

                Toggle("Allow video transcoding", isOn: Binding(
                    get: { tempPolicy.enableVideoPlaybackTranscoding ?? false },
                    set: { tempPolicy.enableVideoPlaybackTranscoding = $0 }
                ))
                .disabled(!isEnabled)

                Toggle("Allow video remuxing", isOn: Binding(
                    get: { tempPolicy.enablePlaybackRemuxing ?? false },
                    set: { tempPolicy.enablePlaybackRemuxing = $0 }
                ))
                .disabled(!isEnabled)

                // TODO: Figure out what this does???
                Toggle("Allow media conversion", isOn: Binding(
                    get: { tempPolicy.enableMediaConversion ?? false },
                    set: { tempPolicy.enableMediaConversion = $0 }
                ))
                .disabled(!isEnabled)

                Toggle("Force remote media transcoding", isOn: Binding(
                    get: { tempPolicy.isForceRemoteSourceTranscoding ?? false },
                    set: { tempPolicy.isForceRemoteSourceTranscoding = $0 }
                ))
                .disabled(!isEnabled)
            }
        }
    }
}
