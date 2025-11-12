//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import JellyfinAPI
import SwiftUI

struct ItemView: View {

    protocol ScrollContainerView: View {

        associatedtype Content: View

        init(viewModel: ItemViewModel, content: @escaping () -> Content)
    }

    @Default(.Customization.itemViewType)
    private var itemViewType

    @Router
    private var router

    @StateObject
    private var viewModel: ItemViewModel
    @StateObject
    private var deleteViewModel: DeleteItemViewModel

    @Injected(\.downloadManager)
    private var downloadManager

    @State
    private var isPresentingConfirmationDialog = false
    @State
    private var isPresentingEventAlert = false
    @State
    private var error: JellyfinAPIError?

    // MARK: - Download Tracking

    @State
    private var downloadTask: DownloadTask?
    @State
    private var downloadError: DownloadError?
    @State
    private var isPresentingDownloadError = false

    private var activeDownload: DownloadTask? {
        downloadManager.task(for: viewModel.item)
    }

    private var completedDownload: DownloadItemDto? {
        guard let itemID = viewModel.item.id else { return nil }
        return downloadManager.downloads.first(where: { $0.id == itemID })
    }

    private var hasAnyDownload: Bool {
        activeDownload != nil || completedDownload != nil
    }

    // MARK: - Can Delete/Edit

    private var canDelete: Bool {
        viewModel.userSession.user.permissions.items.canDelete(item: viewModel.item)
    }

    // MARK: - Can Edit Item

    private var canEdit: Bool {
        viewModel.userSession.user.permissions.items.canEditMetadata(item: viewModel.item)
        // TODO: Enable when Subtitle / Lyric Editing is added
        // || viewModel.userSession.user.permissions.items.canManageLyrics(item: viewModel.item)
        // || viewModel.userSession.user.permissions.items.canManageSubtitles(item: viewModel.item)
    }

    // MARK: - Deletion or Editing is Enabled

    private var enableMenu: Bool {
        canEdit || canDelete
    }

    private static func typeViewModel(for item: BaseItemDto) -> ItemViewModel {
        switch item.type {
        case .boxSet, .person, .musicArtist:
            return CollectionItemViewModel(item: item)
        case .episode:
            return EpisodeItemViewModel(item: item)
        case .movie:
            return MovieItemViewModel(item: item)
        case .musicVideo, .video:
            return ItemViewModel(item: item)
        case .series:
            return SeriesItemViewModel(item: item)
        default:
            assertionFailure("Unsupported item")
            return ItemViewModel(item: item)
        }
    }

    init(item: BaseItemDto) {
        self._viewModel = StateObject(wrappedValue: Self.typeViewModel(for: item))
        self._deleteViewModel = StateObject(wrappedValue: DeleteItemViewModel(item: item))
    }

    @ViewBuilder
    private var scrollContentView: some View {
        switch viewModel.item.type {
        case .boxSet, .person, .musicArtist:
            CollectionItemContentView(viewModel: viewModel as! CollectionItemViewModel)
        case .episode, .musicVideo, .video:
            SimpleItemContentView(viewModel: viewModel)
        case .movie:
            MovieItemContentView(viewModel: viewModel as! MovieItemViewModel)
        case .series:
            SeriesItemContentView(viewModel: viewModel as! SeriesItemViewModel)
        default:
            Text(L10n.notImplementedYetWithType(viewModel.item.type ?? "--"))
        }
    }

    // TODO: break out into pad vs phone views based on item type
    private func scrollContainerView<Content: View>(
        viewModel: ItemViewModel,
        content: @escaping () -> Content
    ) -> any ScrollContainerView {

        if UIDevice.isPad {
            return iPadOSCinematicScrollView(viewModel: viewModel, content: content)
        }

        switch viewModel.item.type {
        case .movie, .series:
            switch itemViewType {
            case .compactPoster:
                return CompactPosterScrollView(viewModel: viewModel, content: content)
            case .compactLogo:
                return CompactLogoScrollView(viewModel: viewModel, content: content)
            case .cinematic:
                return CinematicScrollView(viewModel: viewModel, content: content)
            }
        case .person, .musicArtist:
            return CompactPosterScrollView(viewModel: viewModel, content: content)
        default:
            return SimpleScrollView(viewModel: viewModel, content: content)
        }
    }

    @ViewBuilder
    private var innerBody: some View {
        scrollContainerView(viewModel: viewModel) {
            scrollContentView
        }
        .eraseToAnyView()
    }

    // MARK: - Download UI

    @ViewBuilder
    private var downloadButton: some View {
        if let task = activeDownload {
            DownloadButtonView(task: task, downloadManager: downloadManager)
        } else if let dto = completedDownload {
            CompletedDownloadButtonView(dto: dto, downloadManager: downloadManager)
        } else {
            Button {
                startDownload()
            } label: {
                Label(L10n.downloads, systemImage: "arrow.down.circle")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .content:
                innerBody
                    .navigationTitle(viewModel.item.displayTitle)
            case let .error(error):
                ErrorView(error: error)
            case .initial, .refreshing:
                DelayedProgressView()
            }
        }
        .animation(.linear(duration: 0.1), value: viewModel.state)
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            viewModel.send(.refresh)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                downloadButton
            }
        }
        .navigationBarMenuButton(
            isLoading: viewModel.backgroundStates.contains(.refresh),
            isHidden: !enableMenu
        ) {
            if canEdit {
                Button(L10n.edit, systemImage: "pencil") {
                    router.route(to: .itemEditor(viewModel: viewModel))
                }
            }

            if canDelete {
                Section {
                    Button(L10n.delete, systemImage: "trash", role: .destructive) {
                        isPresentingConfirmationDialog = true
                    }
                }
            }
        }
        .confirmationDialog(
            L10n.deleteItemConfirmationMessage,
            isPresented: $isPresentingConfirmationDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.confirm, role: .destructive) {
                deleteViewModel.send(.delete)
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .onReceive(deleteViewModel.events) { event in
            switch event {
            case let .error(eventError):
                error = eventError
                isPresentingEventAlert = true
            case .deleted:
                router.dismiss()
            }
        }
        .alert(
            L10n.error,
            isPresented: $isPresentingEventAlert,
            presenting: error
        ) { _ in
        } message: { error in
            Text(error.localizedDescription)
        }
        .alert(
            "Download Error",
            isPresented: $isPresentingDownloadError,
            presenting: downloadError
        ) { _ in
        } message: { error in
            Text(error.displayTitle)
        }
    }

    // MARK: - Download Actions

    private func startDownload() {
        Task {
            let task: DownloadTask = .init(viewModel.item)

            do {
                try await downloadManager.download(task: task)
            } catch let error as DownloadError {
                await MainActor.run {
                    downloadError = error
                    isPresentingDownloadError = true
                }
            } catch {
                await MainActor.run {
                    downloadError = .unknown(error.localizedDescription)
                    isPresentingDownloadError = true
                }
            }
        }
    }
}

// MARK: - Download Button View

private struct DownloadButtonView: View {

    @ObservedObject
    var task: DownloadTask

    let downloadManager: DownloadManager

    var body: some View {
        Menu {
            switch task.state {
            case .queued:
                Text("Queued...")
                    .foregroundColor(.secondary)

            case let .downloading(progress):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Downloading: \(Int(progress * 100))%")
                    ProgressView(value: progress)
                }

                Button(L10n.pause, systemImage: "pause.circle") {
                    downloadManager.pause(task: task)
                }

                Button(L10n.cancel, systemImage: "xmark.circle", role: .destructive) {
                    downloadManager.cancel(task: task)
                }

            case .paused:
                Text("Paused")
                    .foregroundColor(.secondary)

                Button("", systemImage: "play.circle") {
                    downloadManager.resume(task: task)
                }

                Button(L10n.cancel, systemImage: "xmark.circle", role: .destructive) {
                    downloadManager.cancel(task: task)
                }

            case .complete:
                // This shouldn't happen as completed tasks are handled by CompletedDownloadButtonView
                // But keeping for safety during transition
                Text(L10n.taskCompleted)
                    .foregroundColor(.green)

            case let .error(error):
                Text("Error: \(error.displayTitle)")
                    .foregroundColor(.red)

                Button(L10n.retry, systemImage: "arrow.clockwise") {
                    task.start()
                }

                Button(L10n.cancel, systemImage: "xmark.circle", role: .destructive) {
                    downloadManager.cancel(task: task)
                }
            }
        } label: {
            downloadIcon
        }
    }

    @ViewBuilder
    private var downloadIcon: some View {
        switch task.state {
        case .queued:
            Label("Queued", systemImage: "arrow.down.circle.dotted")

        case let .downloading(progress):
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "arrow.down")
                    .font(.system(size: 10))
            }

        case .paused:
            Label("Paused", systemImage: "pause.circle.fill")
                .foregroundColor(.orange)

        case .complete:
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)

        case .error:
            Label("Error", systemImage: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Completed Download Button View

private struct CompletedDownloadButtonView: View {

    let dto: DownloadItemDto
    let downloadManager: DownloadManager

    var body: some View {
        Menu {
            Text(L10n.taskCompleted)
                .foregroundColor(.green)

            Button(L10n.delete, systemImage: "trash", role: .destructive) {
                downloadManager.delete(dto: dto)
            }
        } label: {
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}
