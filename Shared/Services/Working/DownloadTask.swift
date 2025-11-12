//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import Foundation
import Get
import JellyfinAPI
import Logging

final class DownloadTask: NSObject, ObservableObject, Identifiable {

    // MARK: - Mode Enum

    enum Mode {
        case direct
        case transcode(
            mediaSource: MediaSourceInfo,
            playerType: VideoPlayerType,
            maxBitrate: PlaybackBitrate,
            compatibilityMode: PlaybackCompatibility
        )
    }

    // MARK: - System Objects

    @Injected(\.currentUserSession)
    var userSession: UserSession!

    @Injected(\.downloadManager)
    private var downloadManager: DownloadManager

    private let logger = Logger.swiftfin()

    // MARK: - Published Variables

    @Published
    var state: DownloadState = .queued {
        didSet {
            onStateChange?(state)
            logger.debug("Download \(id) state changed to \(state)")
        }
    }

    @Published
    var totalBytesExpected: Int64 = 0

    @Published
    var totalBytesDownloaded: Int64 = 0

    // MARK: - Progress Tracking

    private var lastReportedProgress: Double = -1
    private let progressThreshold: Double = 0.01

    // MARK: - Static Variables

    let item: BaseItemDto
    let id: String
    let mode: Mode

    var expectedSize: Int64 {
        if item.canBePlayed {
            let itemSize = item.mediaSources?.first?.size ?? 0
            return Int64(Double(itemSize) * 1.5)
        } else {
            return 10_000_000
        }
    }

    // MARK: - Event Closures

    var onStateChange: ((DownloadState) -> Void)?
    var onProgress: ((Double) -> Void)?
    var onCompletion: ((DownloadItemDto) -> Void)?

    // MARK: - Resume Data

    var resumeData: Data?

    // MARK: - Internal Variables

    private var downloadTask: Task<Void, Never>?
    private var urlSessionTask: URLSessionDownloadTask?

    // MARK: - Transcode Variables

    private var transcodeContinuation: CheckedContinuation<URL, Error>?
    private var transcodeDestinationURL: URL?

    // MARK: - Download Variables

    private var imagesFolder: URL? {
        item.downloadFolder?.appendingPathComponent("Images")
    }

    private var deviceProfile: DeviceProfile? {
        if case let .transcode(_, playerType, maxBitrate, compatibilityMode) = mode {
            return DeviceProfile.build(
                for: playerType,
                compatibilityMode: compatibilityMode,
                maxBitrate: maxBitrate.rawValue
            )
        }
        return nil
    }

    // MARK: - Initializer

    init(
        _ item: BaseItemDto,
        mode: Mode = .direct
    ) {
        self.item = item
        self.mode = mode
        self.id = item.id!
        super.init()
    }

    // MARK: - Start Download

    func start() {
        logger.info("Starting download for: \(item.displayTitle)")

        state = .queued
        lastReportedProgress = -1

        downloadTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await prepareFolder()

                await MainActor.run {
                    self.state = .downloading(0)
                }

                let mediaURL: URL?
                if item.canBePlayed {
                    mediaURL = try await downloadMedia()
                } else {
                    logger.info("Item is not playable, skipping media download: \(item.displayTitle)")
                    mediaURL = nil
                }

                let imagePaths = try await downloadImages()
                let chapterPaths = try await downloadChapterImages()

                // Download parent images for episodes so portrait posters work
                try await downloadParentImagesIfNeeded()

                let dto = buildDownloadItemDTO(
                    mediaURL: mediaURL,
                    imagePaths: imagePaths,
                    chapterImagePaths: chapterPaths
                )

                await MainActor.run {
                    self.state = .complete
                    self.onProgress?(1.0)
                    self.onCompletion?(dto)
                }

                logger.info("Download completed for: \(self.item.displayTitle)")

            } catch is CancellationError {
                await MainActor.run {
                    self.state = .error(.cancelled)
                }
                logger.warning("Download cancelled for: \(self.item.displayTitle)")

            } catch {
                await MainActor.run {
                    self.state = .error(DownloadError(error))
                }
                logger.error("Download failed for \(self.item.displayTitle): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Pause Download

    func pause() {
        logger.info("Pausing download for: \(item.displayTitle)")

        urlSessionTask?.cancel(
            byProducingResumeData: { [weak self] data in
                guard let self else { return }
                self.resumeData = data

                Task { @MainActor in
                    self.state = .paused
                }
            }
        )

        downloadTask?.cancel()
    }

    // MARK: - Resume Download

    func resume() {
        guard case .paused = state else {
            logger.warning("Attempted to resume download that is not paused: \(item.displayTitle)")
            return
        }

        logger.info("Resuming download for: \(item.displayTitle)")

        lastReportedProgress = -1

        if let resumeData {
            urlSessionTask = downloadManager.session.downloadTask(withResumeData: resumeData)

            if let task = urlSessionTask {
                downloadManager.registerTask(task, for: self)
                task.resume()
            }

            Task { @MainActor in
                let progress = totalBytesExpected > 0
                    ? Double(totalBytesDownloaded) / Double(totalBytesExpected)
                    : 0
                self.state = .downloading(progress)
            }
        } else {
            logger.warning("No resume data available, restarting download: \(item.displayTitle)")
            start()
        }
    }

    // MARK: - Cancel Download

    func cancel() {
        logger.info("Cancelling download for: \(item.displayTitle)")

        downloadTask?.cancel()

        if let urlTask = urlSessionTask {
            urlTask.cancel()
            downloadManager.unregisterTask(urlTask)
        }

        Task { @MainActor in
            state = .error(.cancelled)
        }

        if let continuation = transcodeContinuation {
            transcodeContinuation = nil
            continuation.resume(throwing: CancellationError())
        }
    }

    // MARK: - Download Entry

    private func downloadMedia() async throws -> URL {
        guard let itemID = item.id else {
            throw DownloadError(JellyfinAPIError("Missing item ID"))
        }

        guard let userSession = userSession else {
            throw DownloadError(JellyfinAPIError("No user session"))
        }

        switch mode {
        case .direct:
            return try await downloadDirect(
                itemID: itemID,
                userSession: userSession
            )

        case let .transcode(mediaSource, _, maxBitrate, _):
            return try await downloadTranscode(
                itemID: itemID,
                mediaSource: mediaSource,
                maxBitrate: maxBitrate,
                userSession: userSession
            )
        }
    }

    // MARK: - Download (DirectPlay)

    private var directContinuation: CheckedContinuation<URL, Error>?

    private func downloadDirect(
        itemID: String,
        userSession: UserSession
    ) async throws -> URL {
        logger.info("Starting direct download for: \(item.displayTitle)")

        guard let downloadFolder = item.downloadFolder else {
            throw DownloadError(JellyfinAPIError("Download folder not available"))
        }

        let request = Paths.getDownload(itemID: itemID)
        guard let url = userSession.client.fullURL(with: request) else {
            throw JellyfinAPIError("Bad URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue(
            "MediaBrowser Token=\"\(userSession.user.accessToken)\"",
            forHTTPHeaderField: "Authorization"
        )
        urlRequest.timeoutInterval = 300

        let task = downloadManager.session.downloadTask(with: urlRequest)
        downloadManager.registerTask(task, for: self)

        await MainActor.run {
            self.urlSessionTask = task
        }

        task.resume()

        return try await withCheckedThrowingContinuation { continuation in
            self.directContinuation = continuation
        }
    }

    // MARK: - Download (Transcoded)

    private func downloadTranscode(
        itemID: String,
        mediaSource: MediaSourceInfo,
        maxBitrate: PlaybackBitrate,
        userSession: UserSession
    ) async throws -> URL {
        guard let deviceProfile = deviceProfile else {
            throw DownloadError(JellyfinAPIError("Missing device profile"))
        }

        logger.info("Starting transcode download for: \(item.displayTitle)")

        var playbackInfo = PlaybackInfoDto()

        playbackInfo.mediaSourceID = mediaSource.id
        playbackInfo.allowAudioStreamCopy = true
        playbackInfo.allowVideoStreamCopy = true
        playbackInfo.isAutoOpenLiveStream = true
        playbackInfo.deviceProfile = deviceProfile
        playbackInfo.maxStreamingBitrate = maxBitrate.rawValue
        playbackInfo.userID = userSession.user.id

        logger.debug("Requesting playback info for transcode")

        let response = try await userSession.client.send(
            Paths.getPostedPlaybackInfo(
                itemID: itemID,
                playbackInfo
            )
        )

        guard let updatedMediaSource = response.value.mediaSources?.first else {
            throw DownloadError(JellyfinAPIError("No media sources returned from playback info"))
        }

        guard var transcodingURL = updatedMediaSource.transcodingURL else {
            throw DownloadError(JellyfinAPIError("No transcoding URL returned"))
        }

        if let originalSize = updatedMediaSource.size {
            await MainActor.run {
                self.totalBytesExpected = Int64(originalSize)
            }
            logger.debug("Using original file size as transcode estimate: \(originalSize) bytes")
        } else if let bitrate = updatedMediaSource.bitrate, let runTimeTicks = item.runTimeTicks {
            let estimatedSize = Int64((Double(bitrate) / 8.0) * (Double(runTimeTicks) / 10_000_000.0))
            await MainActor.run {
                self.totalBytesExpected = estimatedSize
            }
            logger.debug("Estimated transcode size from bitrate: \(estimatedSize) bytes")
        }

        // Convert HLS manifest to progressive stream for download
        // Replace master.m3u8 with stream.mp4 for downloadable format
        transcodingURL = transcodingURL.replacingOccurrences(
            of: "master.m3u8",
            with: "stream.mp4"
        )

        guard let fullURL = userSession.client.fullURL(with: transcodingURL) else {
            throw DownloadError(JellyfinAPIError("Failed to construct full URL from transcoding URL"))
        }

        logger.info("Downloading transcode stream from: \(fullURL)")

        var request = URLRequest(url: fullURL)
        request.setValue(
            "MediaBrowser Token=\"\(userSession.user.accessToken)\"",
            forHTTPHeaderField: "Authorization"
        )
        request.timeoutInterval = 300

        guard let downloadFolder = item.downloadFolder else {
            throw DownloadError(JellyfinAPIError("Download folder not available"))
        }

        let destinationURL = downloadFolder.appendingPathComponent("Media.mp4")

        try FileManager.default.createDirectory(
            at: downloadFolder,
            withIntermediateDirectories: true
        )

        let task = downloadManager.session.downloadTask(with: request)
        downloadManager.registerTask(task, for: self)

        await MainActor.run {
            self.urlSessionTask = task
        }

        task.resume()

        let result = try await withCheckedThrowingContinuation { continuation in
            self.transcodeContinuation = continuation
            self.transcodeDestinationURL = destinationURL
        }

        logger.info("Transcode download completed for: \(item.displayTitle)")

        return result
    }

    // MARK: - Download Item Images

    private func downloadImages() async throws -> [ImageType: URL] {
        logger.info("Starting image downloads for: \(item.displayTitle)")

        var imagePaths: [ImageType: URL] = [:]

        try await withThrowingTaskGroup(of: (ImageType, URL)?.self) { group in
            if let portraitURL = item.imageSource(.primary).url {
                group.addTask {
                    let path = try await self.downloadImage(
                        from: portraitURL,
                        secondaryName: "Primary"
                    )
                    return (.primary, path)
                }
            }

            if let landscapeURL = item.imageSource(.backdrop).url {
                group.addTask {
                    let path = try await self.downloadImage(
                        from: landscapeURL,
                        secondaryName: "Backdrop"
                    )
                    return (.backdrop, path)
                }
            }

            if let logoURL = item.imageSource(.logo).url {
                group.addTask {
                    let path = try await self.downloadImage(
                        from: logoURL,
                        secondaryName: "Logo"
                    )
                    return (.logo, path)
                }
            }

            if let thumbURL = item.imageSource(.thumb).url {
                group.addTask {
                    let path = try await self.downloadImage(
                        from: thumbURL,
                        secondaryName: "Thumb"
                    )
                    return (.thumb, path)
                }
            }

            for try await result in group {
                if let (type, url) = result {
                    imagePaths[type] = url
                }
            }
        }

        logger.info("Image downloads completed for: \(item.displayTitle)")

        return imagePaths
    }

    // MARK: - Download Chapter Images

    private func downloadChapterImages() async throws -> [URL] {
        guard let chapters = item.chapters?
            .sorted(using: \.startPositionTicks)
            .compacted(using: \.startPositionTicks),
            !chapters.isEmpty
        else {
            logger.debug("No chapters to download images for: \(item.displayTitle)")
            return []
        }

        logger.info("Starting chapter image downloads for: \(item.displayTitle)")

        var chapterPaths: [URL] = []

        await withTaskGroup(of: (Int, URL)?.self) { group in
            for (index, _) in chapters.enumerated() {
                group.addTask {
                    do {
                        let path = try await self.downloadChapterImage(index: index)
                        return (index, path)
                    } catch {
                        self.logger.warning("Failed to download chapter image \(index): \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            for await result in group {
                if let (_, path) = result {
                    chapterPaths.append(path)
                }
            }
        }

        chapterPaths.sort { $0.lastPathComponent < $1.lastPathComponent }

        logger.info("Chapter image downloads completed: \(chapterPaths.count) images for \(item.displayTitle)")

        return chapterPaths
    }

    // MARK: - Download Single Chapter Image

    private func downloadChapterImage(index: Int) async throws -> URL {
        logger.debug("Downloading chapter image \(index)")

        guard let itemID = item.id else {
            throw DownloadError(JellyfinAPIError("Missing item ID"))
        }

        let parameters = Paths.GetItemImageParameters(
            maxWidth: 500,
            quality: 90,
            imageIndex: index
        )

        let request = Paths.getItemImage(
            itemID: itemID,
            imageType: ImageType.chapter.rawValue,
            parameters: parameters
        )

        let imageURL = userSession.client.fullURL(with: request)

        guard let imageURL else {
            throw DownloadError(JellyfinAPIError("Failed to construct chapter image URL"))
        }

        let response = try await userSession.client.download(
            for: .init(url: imageURL).withResponse(URL.self),
            delegate: nil
        )

        return try saveChapterImage(
            response: response,
            index: index
        )
    }

    // MARK: - Save Chapter Image

    private func saveChapterImage(
        response: Response<URL>,
        index: Int
    ) throws -> URL {
        guard let folder = imagesFolder else {
            throw DownloadError(JellyfinAPIError("Images folder not available"))
        }

        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        let fileExtension = response.response.mimeSubtype ?? "jpg"
        let filename = String(format: "Chapter_%02d.\(fileExtension)", index)
        let destinationURL = folder.appendingPathComponent(filename)

        try FileManager.default.moveItem(
            at: response.value,
            to: destinationURL
        )

        logger.debug("Saved chapter image: \(filename)")

        return destinationURL
    }

    // MARK: - Download Parent Images

    private func downloadParentImagesIfNeeded() async throws {
        guard item.type == .episode else { return }

        guard let seriesID = item.seriesID else {
            logger.debug("Episode has no series ID, skipping parent image download")
            return
        }

        // Check if parent already exists in storage
        if StoredValues[.Download.item(id: seriesID)] != nil {
            logger.debug("Parent series already in storage, skipping download")
            return
        }

        logger.info("Downloading parent images for series: \(seriesID)")

        // Fetch the series item
        let request = Paths.getItem(
            itemID: seriesID,
            userID: userSession.user.id
        )
        let response = try await userSession.client.send(request)
        let seriesItem = response.value

        var parentImagePaths: [ImageType: URL] = [:]

        // Download series primary (poster) and backdrop images
        try await withThrowingTaskGroup(of: (ImageType, URL)?.self) { group in
            if let primaryURL = seriesItem.imageSource(ImageType.primary).url {
                group.addTask {
                    let path = try await self.downloadParentImage(
                        from: primaryURL,
                        parentID: seriesID,
                        secondaryName: "Primary"
                    )
                    return (ImageType.primary, path)
                }
            }

            if let backdropURL = seriesItem.imageSource(ImageType.backdrop).url {
                group.addTask {
                    let path = try await self.downloadParentImage(
                        from: backdropURL,
                        parentID: seriesID,
                        secondaryName: "Backdrop"
                    )
                    return (ImageType.backdrop, path)
                }
            }

            if let thumbURL = seriesItem.imageSource(ImageType.thumb).url {
                group.addTask {
                    let path = try await self.downloadParentImage(
                        from: thumbURL,
                        parentID: seriesID,
                        secondaryName: "Thumb"
                    )
                    return (ImageType.thumb, path)
                }
            }

            for try await result in group {
                if let (type, url) = result {
                    parentImagePaths[type] = url
                }
            }
        }

        // Create a minimal DownloadItemDto for the parent with just images
        let parentDto = DownloadItemDto(
            from: seriesItem,
            fileSize: 0,
            mediaPath: nil,
            imagePaths: parentImagePaths
        )

        // Store the parent DTO
        Task { @MainActor in
            StoredValues[.Download.item(id: seriesID)] = parentDto
        }

        logger.info("Parent images downloaded for series: \(seriesID)")
    }

    private func downloadParentImage(
        from url: URL,
        parentID: String,
        secondaryName: String
    ) async throws -> URL {
        logger.debug("Downloading parent image: \(secondaryName)")

        let response = try await userSession.client.download(
            for: .init(url: url).withResponse(URL.self),
            delegate: nil
        )

        return try saveParentImage(
            response: response,
            parentID: parentID,
            secondaryName: secondaryName
        )
    }

    private func saveParentImage(
        response: Response<URL>,
        parentID: String,
        secondaryName: String
    ) throws -> URL {
        let parentFolder = URL.downloads.appendingPathComponent(parentID).appendingPathComponent("Images")

        try FileManager.default.createDirectory(
            at: parentFolder,
            withIntermediateDirectories: true
        )

        let filename = response.response.suggestedFilename
            ?? "\(secondaryName).\(response.response.mimeSubtype ?? "png")"

        let destinationURL = parentFolder.appendingPathComponent(filename)

        try FileManager.default.moveItem(
            at: response.value,
            to: destinationURL
        )

        logger.debug("Saved parent image: \(filename)")

        return destinationURL
    }

    // MARK: - Download Image from URL

    private func downloadImage(
        from url: URL,
        secondaryName: String
    ) async throws -> URL {
        logger.debug("Downloading image: \(secondaryName)")

        let response = try await userSession.client.download(
            for: .init(url: url).withResponse(URL.self),
            delegate: nil
        )

        return try saveImage(
            response: response,
            secondaryName: secondaryName
        )
    }

    private func saveImage(
        response: Response<URL>,
        secondaryName: String
    ) throws -> URL {
        guard let folder = imagesFolder else {
            throw DownloadError(JellyfinAPIError("Images folder not available"))
        }

        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        let filename = response.response.suggestedFilename
            ?? "\(secondaryName).\(response.response.mimeSubtype ?? "png")"

        let destinationURL = folder.appendingPathComponent(filename)

        try FileManager.default.moveItem(
            at: response.value,
            to: destinationURL
        )

        logger.debug("Saved image: \(filename)")

        return destinationURL
    }

    // MARK: Helpers

    private func prepareFolder() async throws {
        guard let folder = item.downloadFolder else { return }

        try? FileManager.default.removeItem(at: folder)

        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        logger.debug("Prepared download folder for: \(item.displayTitle)")
    }

    private func buildDownloadItemDTO(
        mediaURL: URL?,
        imagePaths: [ImageType: URL],
        chapterImagePaths: [URL]
    ) -> DownloadItemDto {
        let fileSize: Int64
        if let mediaURL {
            fileSize = (
                try? FileManager.default.attributesOfItem(
                    atPath: mediaURL.path
                )[.size] as? Int64
            ) ?? 0
        } else {
            fileSize = 0
        }

        return DownloadItemDto(
            from: item,
            fileSize: fileSize,
            mediaPath: mediaURL,
            chapterImagePaths: chapterImagePaths,
            imagePaths: imagePaths
        )
    }
}

// MARK: - Delegate Helper Methods

extension DownloadTask {

    func handleProgressUpdate(bytesWritten: Int64, totalBytes: Int64) {
        totalBytesDownloaded = bytesWritten

        if totalBytes > 0 {
            totalBytesExpected = max(totalBytesExpected, totalBytes)

            let progress = Double(totalBytesDownloaded) / Double(totalBytesExpected)

            if abs(progress - lastReportedProgress) >= progressThreshold {
                lastReportedProgress = progress

                Task { @MainActor in
                    state = .downloading(progress)
                    onProgress?(progress)
                }
            }
        } else if totalBytes == -1 {
            if totalBytesExpected == 0, let originalSize = item.mediaSources?.first?.size {
                totalBytesExpected = Int64(Double(originalSize) * 1.5)
            }

            if totalBytesExpected > 0 {
                let progress = min(Double(totalBytesDownloaded) / Double(totalBytesExpected), 0.99)

                if abs(progress - lastReportedProgress) >= progressThreshold {
                    lastReportedProgress = progress

                    Task { @MainActor in
                        state = .downloading(progress)
                        onProgress?(progress)
                    }
                }
            }

            if totalBytesDownloaded > 0 {
                let megabytes = Double(totalBytesDownloaded) / 1_000_000
                logger.debug("Transcode download progress: \(String(format: "%.1f", megabytes)) MB")
            }
        }
    }

    func handleDownloadFinished(at location: URL, from downloadTask: URLSessionDownloadTask) {
        guard let folder = item.downloadFolder else {
            logger.error("Download folder not available in delegate callback")
            return
        }

        let fileExtension: String

        if let container = item.mediaSources?.first?.container {
            fileExtension = container
        } else {
            fileExtension = "mp4"
        }

        let filename = "Media.\(fileExtension)"
        let destinationURL = folder.appendingPathComponent(filename)

        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(
                at: location,
                to: destinationURL
            )

            Task { @MainActor in
                totalBytesDownloaded = (
                    try? FileManager.default.attributesOfItem(
                        atPath: destinationURL.path
                    )[.size] as? Int64
                ) ?? 0
                totalBytesExpected = totalBytesDownloaded

                state = .downloading(1.0)
                onProgress?(1.0)

                try? await Task.sleep(nanoseconds: 100_000_000)
                state = .complete
            }

            logger.debug("URLSession download finished for: \(item.displayTitle)")

            // Resume any continuation
            if let continuation = transcodeContinuation {
                transcodeContinuation = nil
                continuation.resume(returning: destinationURL)
            } else if let continuation = directContinuation {
                directContinuation = nil
                continuation.resume(returning: destinationURL)
            }

        } catch {
            Task { @MainActor in
                state = .error(DownloadError(error))
            }
            logger.error("Failed to move downloaded file: \(error.localizedDescription)")

            if let continuation = transcodeContinuation {
                transcodeContinuation = nil
                continuation.resume(throwing: error)
            } else if let continuation = directContinuation {
                directContinuation = nil
                continuation.resume(throwing: error)
            }
        }
    }

    func handleError(_ error: Error) {
        if let urlError = error as? URLError,
           urlError.code == .cancelled,
           case .paused = state
        {
            logger.debug("URLSession task cancelled for pause: \(item.displayTitle)")
            return
        }

        Task { @MainActor in
            state = .error(DownloadError(error))
        }

        logger.error("URLSession task completed with error: \(error.localizedDescription)")

        if let continuation = transcodeContinuation {
            transcodeContinuation = nil
            continuation.resume(throwing: error)
        }
    }
}
