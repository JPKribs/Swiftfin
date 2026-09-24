//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

struct MediaSegmentSettingsView: View {

    #if os(tvOS)
    typealias PlatformPicker = ListRowMenu
    #else
    typealias PlatformPicker = Picker
    #endif

    @Default(.VideoPlayer.MediaSegment.configuration)
    private var mediaSegmentConfiguration

    var body: some View {
        Form(systemImage: "forward.end") {
            Section {
                ForEach(MediaSegmentType.allCases, id: \.self) { type in
                    PlatformPicker(type.displayTitle, selection: $mediaSegmentConfiguration[type])
                }

                PlatformPicker(L10n.nextEpisode, selection: $mediaSegmentConfiguration.nextEpisode)
            }

            Section {
                PlatformPicker(L10n.promptDuration, selection: $mediaSegmentConfiguration.promptDuration)
            } footer: {
                Text(L10n.swipeToDismissPrompt)
            }
        }
        .navigationTitle(L10n.mediaSegments.localizedCapitalized)
    }
}
