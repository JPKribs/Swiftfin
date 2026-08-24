//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct ItemOverviewView: View {

    @Router
    private var router

    let item: BaseItemDto

    private var content: some View {
        VStack(alignment: UIDevice.isTV ? .center : .leading, spacing: 10) {
            if let firstTagline = item.taglines?.first {
                Text(firstTagline)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
            }

            if let itemOverview = item.overview {
                Text(itemOverview.richText)
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .edgePadding()
    }

    var body: some View {
        InlinePlatformView {
            ScrollView {
                content
            }
            .scrollIndicators(.hidden)
        } tvOSView: {
            Marquee(axis: .vertical, resetType: .bounce) {
                content
            }
        }
        .navigationTitle(item.displayTitle)
        .toolbarTitleDisplayMode(.inline)
        .navigationBarCloseButton {
            router.dismiss()
        }
    }
}
