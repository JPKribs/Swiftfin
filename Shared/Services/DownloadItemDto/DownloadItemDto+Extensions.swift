//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Algorithms
import AVKit
import Factory
import Foundation
import JellyfinAPI
import MediaPlayer
import Nuke
import SwiftUI

extension DownloadItemDto: Displayable {

    var displayTitle: String {
        name ?? baseItem.name ?? L10n.unknown
    }
}

extension DownloadItemDto: LibraryIdentifiable {

    var unwrappedIDHashOrZero: Int {
        id.hashValue
    }
}

extension DownloadItemDto {

    var avMetadata: [AVMetadataItem] {
        baseItem.avMetadata
    }

    func nowPlayableStaticMetadata(_ image: UIImage? = nil) -> NowPlayableStaticMetadata {
        baseItem.nowPlayableStaticMetadata(image)
    }

    var birthday: Date? {
        baseItem.birthday
    }

    var birthplace: String? {
        baseItem.birthplace
    }

    var deathday: Date? {
        baseItem.deathday
    }

    var episodeLocator: String? {
        baseItem.episodeLocator
    }

    var itemGenres: [ItemGenre]? {
        baseItem.itemGenres
    }

    var isLiveStream: Bool {
        baseItem.isLiveStream
    }

    var isPlayable: Bool {
        baseItem.isPlayable
    }

    @MainActor
    func getNowPlayingImage() async -> UIImage? {
        let imageSources = thumbImageSources()

        guard let firstImage = await ImagePipeline.Swiftfin.other.loadFirstImage(from: imageSources) else {
            let failedSystemContentView = SystemImageContentView(
                systemName: systemImage
            )
            .posterStyle(preferredPosterDisplayType)
            .frame(width: 400)

            return ImageRenderer(content: failedSystemContentView).uiImage
        }

        let image = Image(uiImage: firstImage)
            .resizable()
        let transformedImage = ZStack {
            Rectangle()
                .fill(Color.secondarySystemFill)

            transform(image: image)
        }
        .posterAspectRatio(preferredPosterDisplayType, contentMode: .fit)
        .frame(width: 400)

        return ImageRenderer(content: transformedImage).uiImage
    }

    // TODO: Get from actual local file NOT from BaseItemDto.
    func getPlaybackItemProvider(
        userSession: UserSession
    ) -> MediaPlayerItemProvider {
        switch baseItem.type {
        case .program:
            MediaPlayerItemProvider(item: baseItem) { program in
                guard let channel = try? await baseItem.getChannel(
                    for: program,
                    userSession: userSession
                ),
                    let mediaSource = channel.mediaSources?.first
                else {
                    throw JellyfinAPIError(L10n.unknownError)
                }
                return try await MediaPlayerItem.build(for: program, mediaSource: mediaSource)
            }
        default:
            MediaPlayerItemProvider(item: baseItem) { item in
                guard let mediaSource = item.mediaSources?.first else {
                    throw JellyfinAPIError(L10n.unknownError)
                }
                return try await MediaPlayerItem.build(for: item, mediaSource: mediaSource)
            }
        }
    }

    var runtime: Duration? {
        baseItem.runtime
    }

    var startSeconds: Duration? {
        guard let ticks = offlineUserData?.playbackPositionTicks else { return nil }
        return Duration.ticks(ticks)
    }

    var seasonEpisodeLabel: String? {
        baseItem.seasonEpisodeLabel
    }

    // MARK: Calculations

    var runTimeLabel: String? {
        baseItem.runTimeLabel
    }

    var progressLabel: String? {
        guard let playbackPositionTicks = offlineUserData?.playbackPositionTicks,
              let totalTicks = baseItem.runTimeTicks,
              playbackPositionTicks != 0,
              totalTicks != 0 else { return nil }

        let remainingSeconds = (totalTicks - playbackPositionTicks) / 10_000_000

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated

        return formatter.string(from: .init(remainingSeconds))
    }

    // TODO: Get from actual local file NOT from BaseItemDto.
    var subtitleStreams: [MediaStream] {
        baseItem.mediaStreams?.filter { $0.type == .subtitle } ?? []
    }

    var audioStreams: [MediaStream] {
        baseItem.mediaStreams?.filter { $0.type == .audio } ?? []
    }

    var videoStreams: [MediaStream] {
        baseItem.mediaStreams?.filter { $0.type == .video } ?? []
    }

    // MARK: Missing and Unaired

    var isMissing: Bool {
        // TODO: Get from actual healthcheck
        false
    }

    var isUnaired: Bool {
        baseItem.isUnaired
    }

    var airDateLabel: String? {
        baseItem.airDateLabel
    }

    var premiereDateLabel: String? {
        baseItem.premiereDateLabel
    }

    var premiereDateYear: String? {
        baseItem.premiereDateYear
    }

    var hasExternalLinks: Bool {
        baseItem.hasExternalLinks
    }

    var hasRatings: Bool {
        baseItem.hasRatings
    }

    // MARK: Chapter Images

    var fullChapterInfo: [ChapterInfo.FullInfo]? {

        guard let chapters = baseItem.chapters?
            .sorted(using: \.startPositionTicks)
            .compacted(using: \.startPositionTicks) else { return nil }

        return chapters
            .enumerated()
            .map { i, chapter in

                let imageSource: ImageSource
                if i < chapterImagePaths.count {
                    imageSource = .init(url: chapterImagePaths[i])
                } else {
                    let parameters = Paths.GetItemImageParameters(
                        maxWidth: 500,
                        quality: 90,
                        imageIndex: i
                    )

                    let request = Paths.getItemImage(
                        itemID: id ?? "",
                        imageType: ImageType.chapter.rawValue,
                        parameters: parameters
                    )

                    let imageURL = Container.shared.currentUserSession()!
                        .client
                        .fullURL(with: request)

                    imageSource = .init(url: imageURL)
                }

                return .init(
                    chapterInfo: chapter,
                    imageSource: imageSource
                )
            }
    }

    var alternateTitle: String? {
        baseItem.alternateTitle
    }

    var presentPlayButton: Bool {
        baseItem.presentPlayButton
    }

    var canBePlayed: Bool {
        baseItem.canBePlayed
    }

    var playButtonLabel: String {
        baseItem.playButtonLabel
    }

    var parentTitle: String? {
        baseItem.parentTitle
    }

    func getFullItem() async throws -> BaseItemDto {
        baseItem
    }
}
