//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Foundation
import JellyfinAPI
import SwiftUI

extension DownloadItemDto: Poster {

    var preferredPosterDisplayType: PosterDisplayType {
        baseItem.preferredPosterDisplayType
    }

    var subtitle: String? {
        baseItem.subtitle
    }

    var showTitle: Bool {
        baseItem.showTitle
    }

    var systemImage: String {
        baseItem.systemImage
    }

    func portraitImageSources(maxWidth: CGFloat? = nil, quality: Int? = nil) -> [ImageSource] {
        switch baseItem.type {
        case .episode:
            [parentImageSource(.primary, parentID: baseItem.seriesID)]
        case .boxSet, .channel, .liveTvChannel, .movie, .musicArtist, .person, .series, .tvChannel:
            [imageSource(.primary)]
        default:
            []
        }
    }

    func landscapeImageSources(maxWidth: CGFloat? = nil, quality: Int? = nil) -> [ImageSource] {
        switch baseItem.type {
        case .episode:
            if Defaults[.Customization.Episodes.useSeriesLandscapeBackdrop] {
                [
                    parentImageSource(.thumb, parentID: baseItem.seriesID),
                    parentImageSource(.backdrop, parentID: baseItem.seriesID),
                    imageSource(.primary),
                ]
            } else {
                [imageSource(.primary)]
            }
        case .folder, .program, .musicVideo, .video:
            [imageSource(.primary)]
        default:
            [
                imageSource(.thumb),
                imageSource(.backdrop),
            ]
        }
    }

    func cinematicImageSources(maxWidth: CGFloat? = nil, quality: Int? = nil) -> [ImageSource] {
        switch baseItem.type {
        case .episode:
            [parentImageSource(.backdrop, parentID: baseItem.seriesID)]
        default:
            [imageSource(.backdrop)]
        }
    }

    func squareImageSources(maxWidth: CGFloat? = nil, quality: Int? = nil) -> [ImageSource] {
        switch baseItem.type {
        case .audio, .channel, .musicAlbum, .tvChannel:
            [imageSource(.primary)]
        default:
            []
        }
    }

    func thumbImageSources(maxWidth: CGFloat? = nil, quality: Int? = nil) -> [ImageSource] {
        switch preferredPosterDisplayType {
        case .portrait:
            portraitImageSources(maxWidth: maxWidth, quality: quality)
        case .landscape:
            landscapeImageSources(maxWidth: maxWidth, quality: quality)
        case .square:
            squareImageSources(maxWidth: maxWidth, quality: quality)
        }
    }

    @ViewBuilder
    func transform(image: Image) -> some View {
        switch baseItem.type {
        case .channel, .tvChannel:
            ContainerRelativeView(ratio: 0.95) {
                image
                    .aspectRatio(contentMode: .fit)
            }
        default:
            image
                .aspectRatio(contentMode: .fill)
        }
    }
}
