//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Factory
import Foundation
import JellyfinAPI

final class ChannelLibraryViewModel: PagingLibraryViewModel<ChannelProgram> {

    /// The date whose programming should be displayed.
    /// Changing this and calling `.refresh` will fetch programs for the new day.
    var selectedDate: Date = .now

    override func get(page: Int) async throws -> [ChannelProgram] {

        var parameters = Paths.GetLiveTvChannelsParameters()
        parameters.fields = .MinimumFields
        parameters.userID = userSession.user.id
        parameters.sortBy = [ItemSortBy.name]

        parameters.limit = pageSize
        parameters.startIndex = page * pageSize

        let request = Paths.getLiveTvChannels(parameters: parameters)
        let response = try await userSession.client.send(request)

        return try await getPrograms(for: response.value.items ?? [])
    }

    private func getPrograms(for channels: [BaseItemDto]) async throws -> [ChannelProgram] {

        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(selectedDate)

        let minEndDate: Date
        let maxStartDate: Date

        if isToday {
            // Show from 1 hour ago through end of today
            minEndDate = calendar.date(byAdding: .hour, value: -1, to: .now) ?? .now
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
            maxStartDate = calendar.startOfDay(for: tomorrow)
        } else {
            // Show the full selected day
            minEndDate = calendar.startOfDay(for: selectedDate)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            maxStartDate = calendar.startOfDay(for: nextDay)
        }

        var parameters = Paths.GetLiveTvProgramsParameters()
        parameters.channelIDs = channels.compactMap(\.id)
        parameters.userID = userSession.user.id
        parameters.maxStartDate = maxStartDate
        parameters.minEndDate = minEndDate
        parameters.sortBy = [ItemSortBy.startDate]

        let request = Paths.getLiveTvPrograms(parameters: parameters)
        let response = try await userSession.client.send(request)

        let groupedPrograms = (response.value.items ?? [])
            .grouped { program in
                channels.first(where: { $0.id == program.channelID })
            }

        return channels
            .reduce(into: [:]) { partialResult, channel in
                partialResult[channel] = (groupedPrograms[channel] ?? [])
                    .sorted(using: \.startDate)
            }
            .map(ChannelProgram.init)
            .sorted(using: \.channel.name)
    }
}
