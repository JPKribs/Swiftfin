//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Factory
import Files
import Foundation
import JellyfinAPI
import Logging

// MARK: - Box Helper

private class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}

extension Container {
    var downloadManager: Factory<DownloadManager> { self { DownloadManager() }.shared }
}

class DownloadManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published
    private(set) var queue: [DownloadTask] = []

    @Published
    private(set) var downloads: [DownloadItemDto] = []

    @Published
    private(set) var expectedStorageUsage: Int64 = 0

    // MARK: - Constants

    private let maxConcurrentDownloads = 3

    // MARK: - Background Session

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.jellyfin.swiftfin.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private var taskMap: [Int: DownloadTask] = [:]

    // MARK: - Logger

    private let logger = Logger.swiftfin()

    // MARK: - Initializer

    override fileprivate init() {
        super.init()

        logger.info("Initializing DownloadManager")

        createDownloadDirectory()
        migrateCompletedItems()
        validateAndCleanupQueue()
        validateAndCleanupCompletedDownloads()
        restoreDownloads()
        calculateExpectedStorage()
    }

    // MARK: - Create Download Task

    var session: URLSession {
        backgroundSession
    }

    func registerTask(_ urlTask: URLSessionTask, for downloadTask: DownloadTask) {
        taskMap[urlTask.taskIdentifier] = downloadTask
        logger.debug("Registered URLSession task \(urlTask.taskIdentifier) for download: \(downloadTask.item.displayTitle)")
    }

    func unregisterTask(_ urlTask: URLSessionTask) {
        taskMap.removeValue(forKey: urlTask.taskIdentifier)
        logger.debug("Unregistered URLSession task \(urlTask.taskIdentifier)")
    }

    func download(task: DownloadTask) async throws {
        guard task.item.id != nil else {
            logger.error("Attempted to download item without ID")
            throw DownloadError(JellyfinAPIError("Item missing ID"))
        }

        guard !queue.contains(where: { $0.id == task.id }) else {
            logger.warning("Download already exists for item: \(task.item.displayTitle)")
            return
        }

        let children = try await fetchChildrenIfNeeded(for: task.item)

        let allTasks = [task] + children.map { DownloadTask($0, mode: task.mode) }

        let totalSize = try await calculateTotalSize(for: allTasks)

        try validateStorage(requiredBytes: totalSize)

        logger.info("Adding \(allTasks.count) download(s) to queue: \(task.item.displayTitle)")

        for downloadTask in allTasks {
            guard let taskItemID = downloadTask.item.id else { continue }

            await MainActor.run {
                queue.append(downloadTask)
                addToQueueStorage(itemID: taskItemID)
                updateExpectedStorage(adding: downloadTask.expectedSize)
                configureTaskCallbacks(task: downloadTask)
            }
        }

        startNextDownloads()
    }

    // MARK: - Pause Download Task

    func pause(task: DownloadTask) {
        guard let itemID = task.item.id else { return }

        logger.info("Pausing download: \(task.item.displayTitle)")

        task.pause()

        Task { @MainActor in
            StoredValues[.Download.resumeData(id: itemID)] = task.resumeData
            StoredValues[.Download.state(id: itemID)] = task.state
        }
    }

    // MARK: - Resume Download Task

    func resume(task: DownloadTask) {
        logger.info("Resuming download: \(task.item.displayTitle)")

        task.resume()
    }

    // MARK: - Cancel Download Task

    func cancel(task: DownloadTask) {
        guard let itemID = task.item.id else { return }

        logger.info("Cancelling download: \(task.item.displayTitle)")

        task.cancel()

        Task { @MainActor in
            queue.removeAll(where: { $0.id == task.id })
            removeFromQueueStorage(itemID: itemID)

            StoredValues[.Download.resumeData(id: itemID)] = nil
        }

        startNextDownloads()
    }

    func delete(task: DownloadTask) {
        guard let itemID = task.item.id else { return }

        logger.info("Deleting download: \(task.item.displayTitle)")

        task.cancel()

        if let dto = StoredValues[.Download.item(id: itemID)] {
            try? dto.delete()
        }

        updateExpectedStorage(removing: task.expectedSize)

        Task { @MainActor in
            queue.removeAll(where: { $0.id == task.id })
            downloads.removeAll(where: { $0.id == itemID })

            removeFromQueueStorage(itemID: itemID)
            removeFromCompletedStorage(itemID: itemID)

            StoredValues[.Download.item(id: itemID)] = nil
            StoredValues[.Download.resumeData(id: itemID)] = nil
        }

        logger.debug("Deleted \(task.item.displayTitle) from storage")
    }

    func delete(dto: DownloadItemDto) {
        guard let itemID = dto.id else { return }

        logger.info("Deleting completed download: \(dto.displayTitle)")

        try? dto.delete()

        Task { @MainActor in
            downloads.removeAll(where: { $0.id == itemID })
            removeFromCompletedStorage(itemID: itemID)

            StoredValues[.Download.item(id: itemID)] = nil
        }

        logger.debug("Deleted \(dto.displayTitle) from downloads")
    }

    // MARK: - Restore a Download Task

    func task(for item: BaseItemDto) -> DownloadTask? {
        guard let itemID = item.id else { return nil }

        // Check if it's in the active queue
        if let existingTask = queue.first(where: { $0.id == itemID }) {
            return existingTask
        }

        // Don't restore if it's already complete
        let state = StoredValues[.Download.state(id: itemID)]
        if state == .complete {
            return nil
        }

        // Try to restore the task
        return restoreTask(id: itemID)
    }

    // MARK: - Get Downloaded Items

    func downloadedItems() -> [DownloadItemDto] {
        downloads
    }

    func validateDownloads() -> [String: Bool] {
        var results: [String: Bool] = [:]

        let completedIDs = StoredValues[.Download.completedIDs]

        for id in completedIDs {
            if let dto = StoredValues[.Download.item(id: id)] {
                results[id] = dto.validate()
            } else {
                results[id] = false
            }
        }

        return results
    }

    func cleanupInvalidDownloads() {
        let completedIDs = StoredValues[.Download.completedIDs]
        var validIDs: [String] = []
        var cleanedCount = 0

        for id in completedIDs {
            if let dto = StoredValues[.Download.item(id: id)], dto.validate() {
                validIDs.append(id)
            } else {
                cleanupInvalidDownload(id: id)
                cleanedCount += 1
            }
        }

        Task { @MainActor in
            StoredValues[.Download.completedIDs] = validIDs

            self.downloads.removeAll { dto in
                guard let itemID = dto.id else { return false }
                return !validIDs.contains(itemID)
            }
        }

        logger.info("Cleaned up \(cleanedCount) invalid downloads")
    }

    // MARK: - Create Download Directory

    private func createDownloadDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: URL.downloads,
                withIntermediateDirectories: true
            )
            logger.debug("Created download directory at: \(URL.downloads)")
        } catch {
            logger.error("Failed to create download directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup Missing Downloads

    private func cleanupQueue() {
        do {
            try FileManager.default.createDirectory(
                at: URL.downloads,
                withIntermediateDirectories: true
            )
            logger.debug("Created download directory at: \(URL.downloads)")
        } catch {
            logger.error("Failed to create download directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Queue Management

    private func addToQueueStorage(itemID: String) {
        var queueIDs = StoredValues[.Download.queueIDs]

        guard !queueIDs.contains(itemID) else {
            logger.debug("Item \(itemID) already in queue storage")
            return
        }

        queueIDs.append(itemID)

        Task { @MainActor in
            StoredValues[.Download.queueIDs] = queueIDs
        }

        logger.debug("Added \(itemID) to queue storage")
    }

    private func removeFromQueueStorage(itemID: String) {
        var queueIDs = StoredValues[.Download.queueIDs]
        queueIDs.removeAll(where: { $0 == itemID })

        Task { @MainActor in
            StoredValues[.Download.queueIDs] = queueIDs
        }

        logger.debug("Removed \(itemID) from queue storage")
    }

    private func addToCompletedStorage(itemID: String) {
        var completedIDs = StoredValues[.Download.completedIDs]

        guard !completedIDs.contains(itemID) else {
            logger.debug("Item \(itemID) already in completed storage")
            return
        }

        completedIDs.append(itemID)

        Task { @MainActor in
            StoredValues[.Download.completedIDs] = completedIDs
        }

        logger.debug("Added \(itemID) to completed storage")
    }

    private func removeFromCompletedStorage(itemID: String) {
        var completedIDs = StoredValues[.Download.completedIDs]
        completedIDs.removeAll(where: { $0 == itemID })

        Task { @MainActor in
            StoredValues[.Download.completedIDs] = completedIDs
        }

        logger.debug("Removed \(itemID) from completed storage")
    }

    // MARK: - Concurrent Download Management

    private func startNextDownloads() {
        let activeCount = queue.filter { task in
            if case .downloading = task.state {
                return true
            }
            return false
        }.count

        let availableSlots = max(0, maxConcurrentDownloads - activeCount)

        guard availableSlots > 0 else {
            logger.debug("All download slots full (\(maxConcurrentDownloads) active)")
            return
        }

        let queuedTasks = queue.filter { $0.state == .queued }.prefix(availableSlots)

        for task in queuedTasks {
            logger.info("Starting queued download: \(task.item.displayTitle)")
            task.start()
        }
    }

    // MARK: - Restore

    private func restoreDownloads() {
        restoreCompletedDownloads()
        restoreQueue()
    }

    private func restoreCompletedDownloads() {
        let completedIDs = StoredValues[.Download.completedIDs]

        logger.info("Restoring \(completedIDs.count) completed downloads")

        var validIDs: [String] = []
        var restoredDownloads: [DownloadItemDto] = []

        for id in completedIDs {
            if let dto = StoredValues[.Download.item(id: id)], dto.validate() {
                restoredDownloads.append(dto)
                validIDs.append(id)
                logger.debug("Restored completed download: \(dto.displayTitle)")
            } else {
                logger.warning("Invalid completed download found for ID: \(id), removing")
                cleanupInvalidDownload(id: id)
            }
        }

        // Update published property on MainActor
        Task { @MainActor in
            self.downloads = restoredDownloads
        }

        if validIDs.count != completedIDs.count {
            Task { @MainActor in
                StoredValues[.Download.completedIDs] = validIDs
            }
            logger.info("Cleaned up \(completedIDs.count - validIDs.count) invalid completed downloads")
        }
    }

    private func restoreQueue() {
        let queueIDs = StoredValues[.Download.queueIDs]

        logger.info("Restoring \(queueIDs.count) items from queue")

        var validIDs: [String] = []
        var restoredQueue: [DownloadTask] = []

        for id in queueIDs {
            if let task = restoreTask(id: id) {
                restoredQueue.append(task)
                validIDs.append(id)
                logger.info("Restored queued task: \(task.item.displayTitle)")
            } else {
                logger.warning("Failed to restore task for ID: \(id), removing from queue")
                cleanupInvalidDownload(id: id)
            }
        }

        // Update published property on MainActor
        Task { @MainActor in
            self.queue = restoredQueue
        }

        if validIDs.count != queueIDs.count {
            StoredValues[.Download.queueIDs] = validIDs
            logger.info("Cleaned up \(queueIDs.count - validIDs.count) invalid queue items")
        }

        startNextDownloads()
    }

    private func restoreTask(id: String) -> DownloadTask? {
        let state = StoredValues[.Download.state(id: id)]
        let resumeData = StoredValues[.Download.resumeData(id: id)]

        guard state != .complete else {
            logger.debug("Task \(id) is complete, skipping queue restore")
            return nil
        }

        // Check if we have a valid DTO - if not, this was cleaned up
        guard let dto = StoredValues[.Download.item(id: id)] else {
            logger.debug("No stored DTO for \(id), cannot restore")
            return nil
        }

        let task = DownloadTask(dto.baseItem)

        task.state = state
        task.resumeData = resumeData

        configureTaskCallbacks(task: task)

        logger.debug("Restored download task for: \(id)")

        return task
    }

    private func cleanupInvalidDownload(id: String) {
        if let dto = StoredValues[.Download.item(id: id)] {
            try? dto.deleteMedia()
        }

        StoredValues[.Download.item(id: id)] = nil
        StoredValues[.Download.resumeData(id: id)] = nil
    }

    // MARK: - Task Configuration

    private func configureTaskCallbacks(task: DownloadTask) {
        guard let itemID = task.item.id else { return }

        task.onStateChange = { [weak self] state in
            Task { @MainActor in
                StoredValues[.Download.state(id: itemID)] = state
            }

            if case .downloading = state {
                // State changed, no logging needed for every update
            } else {
                self?.logger.info("Download \(itemID) state changed to: \(state)")
            }
        }

        let lastLoggedProgress = Box(-1)
        task.onProgress = { [weak self] progress in
            let percent = Int(progress * 100)
            if percent != lastLoggedProgress.value && percent % 5 == 0 {
                lastLoggedProgress.value = percent
                self?.logger.info("Download \(itemID) progress: \(percent)%")
            }
        }

        task.onCompletion = { [weak self] dto in
            guard let self else { return }

            Task { @MainActor in
                StoredValues[.Download.item(id: itemID)] = dto
                StoredValues[.Download.state(id: itemID)] = .complete
                StoredValues[.Download.resumeData(id: itemID)] = nil

                self.queue.removeAll(where: { $0.id == itemID })
                self.downloads.append(dto)

                self.removeFromQueueStorage(itemID: itemID)
                self.addToCompletedStorage(itemID: itemID)
            }

            self.updateExpectedStorage(removing: task.expectedSize)

            self.logger.info("Download completed: \(dto.displayTitle)")

            self.startNextDownloads()
        }
    }

    // MARK: - Storage Management

    private func validateStorage(requiredBytes: Int64) throws {
        let fileURL = URL.downloads
        guard let values = try? fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let availableCapacity = values.volumeAvailableCapacityForImportantUsage
        else {
            logger.warning("Could not determine available storage, proceeding with download")
            return
        }

        let availableAfterQueue = availableCapacity - expectedStorageUsage

        if availableAfterQueue < requiredBytes {
            let availableGB = Double(availableAfterQueue) / 1_000_000_000
            let requiredGB = Double(requiredBytes) / 1_000_000_000

            logger
                .error(
                    "Insufficient storage: available \(String(format: "%.2f", availableGB))GB, required \(String(format: "%.2f", requiredGB))GB"
                )
            throw DownloadError.insufficientStorage
        }

        logger.info("Storage check passed: \(String(format: "%.2f", Double(availableAfterQueue) / 1_000_000_000))GB available")
    }

    private func calculateExpectedStorage() {
        var total: Int64 = 0

        for task in queue where task.state != .complete {
            total += task.expectedSize
        }

        Task { @MainActor in
            self.expectedStorageUsage = total
        }

        logger.debug("Calculated expected storage: \(String(format: "%.2f", Double(total) / 1_000_000_000))GB")
    }

    private func updateExpectedStorage(adding bytes: Int64) {
        Task { @MainActor in
            self.expectedStorageUsage += bytes
        }
    }

    private func updateExpectedStorage(removing bytes: Int64) {
        Task { @MainActor in
            self.expectedStorageUsage = max(0, self.expectedStorageUsage - bytes)
        }
    }

    // MARK: - Collection Children

    private func fetchChildrenIfNeeded(for item: BaseItemDto) async throws -> [BaseItemDto] {
        guard let itemID = item.id else { return [] }

        switch item.type {
        case .series:
            return try await fetchSeriesChildren(seriesID: itemID)
        case .season:
            return try await fetchSeasonEpisodes(seasonID: itemID)
        case .musicAlbum:
            return try await fetchAlbumTracks(albumID: itemID)
        case .musicArtist:
            return try await fetchArtistAlbums(artistID: itemID)
        default:
            return []
        }
    }

    private func fetchSeriesChildren(seriesID: String) async throws -> [BaseItemDto] {
        logger.info("Fetching all episodes for series: \(seriesID)")

        guard let userSession = Container.shared.currentUserSession() else {
            throw DownloadError(JellyfinAPIError("No user session"))
        }

        let parameters = Paths.GetItemsParameters(
            userID: userSession.user.id,
            isRecursive: true,
            parentID: seriesID,
            fields: ItemFields.allCases,
            includeItemTypes: [.episode]
        )

        let request = Paths.getItems(parameters: parameters)
        let response = try await userSession.client.send(request)

        let episodes = response.value.items ?? []
        logger.info("Found \(episodes.count) episodes for series")

        return episodes
    }

    private func fetchSeasonEpisodes(seasonID: String) async throws -> [BaseItemDto] {
        logger.info("Fetching episodes for season: \(seasonID)")

        guard let userSession = Container.shared.currentUserSession() else {
            throw DownloadError(JellyfinAPIError("No user session"))
        }

        let parameters = Paths.GetItemsParameters(
            userID: userSession.user.id,
            parentID: seasonID,
            fields: ItemFields.allCases,
            includeItemTypes: [.episode]
        )

        let request = Paths.getItems(parameters: parameters)
        let response = try await userSession.client.send(request)

        let episodes = response.value.items ?? []
        logger.info("Found \(episodes.count) episodes for season")

        return episodes
    }

    private func fetchAlbumTracks(albumID: String) async throws -> [BaseItemDto] {
        logger.info("Fetching tracks for album: \(albumID)")

        guard let userSession = Container.shared.currentUserSession() else {
            throw DownloadError(JellyfinAPIError("No user session"))
        }

        let parameters = Paths.GetItemsParameters(
            userID: userSession.user.id,
            parentID: albumID,
            fields: ItemFields.allCases,
            includeItemTypes: [.audio]
        )

        let request = Paths.getItems(parameters: parameters)
        let response = try await userSession.client.send(request)

        let tracks = response.value.items ?? []
        logger.info("Found \(tracks.count) tracks for album")

        return tracks
    }

    private func fetchArtistAlbums(artistID: String) async throws -> [BaseItemDto] {
        logger.info("Fetching albums for artist: \(artistID)")

        guard let userSession = Container.shared.currentUserSession() else {
            throw DownloadError(JellyfinAPIError("No user session"))
        }

        let albumParameters = Paths.GetItemsParameters(
            userID: userSession.user.id,
            isRecursive: true,
            fields: ItemFields.allCases,
            includeItemTypes: [.musicAlbum],
            artistIDs: [artistID]
        )

        let albumRequest = Paths.getItems(parameters: albumParameters)
        let albumResponse = try await userSession.client.send(albumRequest)

        let albums = albumResponse.value.items ?? []
        logger.info("Found \(albums.count) albums for artist")

        var allItems: [BaseItemDto] = albums

        for album in albums {
            guard let albumID = album.id else { continue }
            let tracks = try await fetchAlbumTracks(albumID: albumID)
            allItems.append(contentsOf: tracks)
        }

        logger.info("Total items (albums + tracks) for artist: \(allItems.count)")

        return allItems
    }

    private func calculateTotalSize(for tasks: [DownloadTask]) async throws -> Int64 {
        var total: Int64 = 0

        for task in tasks {
            if task.item.canBePlayed {
                let itemSize = task.item.mediaSources?.first?.size ?? 0
                total += Int64(Double(itemSize) * 1.5)
            } else {
                total += 10_000_000
            }
        }

        return total
    }

    // MARK: - Validation

    private func validateAndCleanupQueue() {
        logger.info("Validating queue items")

        let queueIDs = StoredValues[.Download.queueIDs]
        var validIDs: [String] = []
        var cleanedCount = 0

        for id in queueIDs {
            let state = StoredValues[.Download.state(id: id)]

            // Skip items that are already complete (migration will handle these)
            guard state != .complete else {
                validIDs.append(id)
                continue
            }

            // Check if we have the necessary data to restore this item
            let canRestore = canRestoreQueueItem(id: id, state: state)

            if canRestore {
                validIDs.append(id)
                logger.debug("Validated queue item: \(id)")
            } else {
                logger.warning("Invalid queue item found for ID: \(id), removing")
                cleanupInvalidDownload(id: id)
                cleanedCount += 1
            }
        }

        if cleanedCount > 0 {
            StoredValues[.Download.queueIDs] = validIDs
            logger.info("Cleaned up \(cleanedCount) invalid queue items")
        }
    }

    private func canRestoreQueueItem(id: String, state: DownloadState) -> Bool {
        // If paused, we need resume data
        if case .paused = state {
            return StoredValues[.Download.resumeData(id: id)] != nil
        }

        // For other states (queued, downloading, error), we can restore
        return true
    }

    private func validateAndCleanupCompletedDownloads() {
        let completedIDs = StoredValues[.Download.completedIDs]

        logger.info("Validating completed downloads")
        logger.debug("Completed IDs in storage: \(completedIDs)")

        var validIDs: [String] = []
        var cleanedCount = 0

        for id in completedIDs {
            let dto = StoredValues[.Download.item(id: id)]

            if dto == nil {
                logger.warning("No DTO found for ID: \(id), removing")
                cleanupInvalidDownload(id: id)
                cleanedCount += 1
                continue
            }

            if let dto = dto, dto.validate() {
                validIDs.append(id)
                logger.debug("Validated download: \(dto.displayTitle)")
            } else {
                logger.warning("Invalid completed download found for ID: \(id), removing")
                cleanupInvalidDownload(id: id)
                cleanedCount += 1
            }
        }

        if cleanedCount > 0 {
            StoredValues[.Download.completedIDs] = validIDs
            logger.info("Cleaned up \(cleanedCount) invalid completed downloads")
        }
    }

    private func migrateCompletedItems() {
        var queueIDs = StoredValues[.Download.queueIDs]
        var completedIDs = StoredValues[.Download.completedIDs]
        var itemsToMigrate: [String] = []

        for id in queueIDs {
            let state = StoredValues[.Download.state(id: id)]
            if state == .complete, !completedIDs.contains(id) {
                itemsToMigrate.append(id)
            }
        }

        if !itemsToMigrate.isEmpty {
            logger.info("Migrating \(itemsToMigrate.count) completed items from queue to completed storage")

            for id in itemsToMigrate {
                queueIDs.removeAll(where: { $0 == id })
                completedIDs.append(id)
            }

            StoredValues[.Download.queueIDs] = queueIDs
            StoredValues[.Download.completedIDs] = completedIDs
        }
    }
}

// MARK: URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let task = taskMap[downloadTask.taskIdentifier] else {
            logger.warning("No DownloadTask found for URLSession task \(downloadTask.taskIdentifier)")
            return
        }

        task.handleDownloadFinished(at: location, from: downloadTask)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let task = taskMap[downloadTask.taskIdentifier] else {
            return
        }

        task.handleProgressUpdate(
            bytesWritten: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let downloadTask = taskMap[task.taskIdentifier] else {
            return
        }

        if let error {
            downloadTask.handleError(error)
        }

        unregisterTask(task)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.info("Background URLSession finished all events")
    }
}
