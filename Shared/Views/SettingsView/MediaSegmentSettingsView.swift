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
                ForEach(MediaSegmentType.supportedCases, id: \.self) { type in
                    PlatformPicker(type.displayTitle, selection: $mediaSegmentConfiguration[type])
                }

                DurationPicker(
                    title: L10n.nextEpisode,
                    selection: $mediaSegmentConfiguration.nextEpisode,
                    noneTitle: L10n.disabled,
                    options: [.seconds(15), .seconds(30), .seconds(60)]
                )
            }

            Section {
                DurationPicker(
                    title: L10n.promptDuration,
                    selection: $mediaSegmentConfiguration.promptDuration,
                    noneTitle: L10n.fullDuration
                )
            } footer: {
                Text(UIDevice.isTV ? L10n.pressToDismissPrompt : L10n.swipeToDismissPrompt)
            }
        }
        .navigationTitle(L10n.mediaSegments.localizedCapitalized)
    }
}
