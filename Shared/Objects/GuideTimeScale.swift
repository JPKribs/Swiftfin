//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

/// Layout constants and time-to-pixel conversion for the EPG guide grid.
enum GuideTimeScale {

    static let pointsPerHour: CGFloat = {
        #if os(tvOS)
        return 600
        #else
        if UIDevice.isPad {
            return 400
        } else {
            return 300
        }
        #endif
    }()

    static let rowHeight: CGFloat = {
        #if os(tvOS)
        return 100
        #else
        if UIDevice.isPad {
            return 64
        } else {
            return 60
        }
        #endif
    }()

    static let channelColumnWidth: CGFloat = {
        #if os(tvOS)
        return 200
        #else
        if UIDevice.isPad {
            return 130
        } else {
            return 100
        }
        #endif
    }()

    /// Size of the channel logo image in the channel column.
    static let channelImageSize: CGFloat = {
        #if os(tvOS)
        return 50
        #else
        if UIDevice.isPad {
            return 40
        } else {
            return 30
        }
        #endif
    }()

    static let timeHeaderHeight: CGFloat = {
        #if os(tvOS)
        return 50
        #else
        if UIDevice.isPad {
            return 36
        } else {
            return 30
        }
        #endif
    }()

    /// Minimum width for a program cell — the width of a 60-second interval.
    /// Keeps very short programs visible without distorting the time scale.
    static let minimumCellWidth: CGFloat = pointsPerHour / 60

    /// Horizontal gap between adjacent program cells within a row.
    static let cellGap: CGFloat = {
        #if os(tvOS)
        return 6
        #else
        if UIDevice.isPad {
            return 3
        } else {
            return 2
        }
        #endif
    }()

    /// Duration threshold (in seconds) below which adjacent programs
    /// are grouped into a single Menu cell.
    static let groupingThreshold: TimeInterval = 15 * 60

    /// Vertical spacing between channel rows in the guide grid.
    static let rowSpacing: CGFloat = {
        #if os(tvOS)
        return 20
        #else
        if UIDevice.isPad {
            return 6
        } else {
            return 4
        }
        #endif
    }()

    /// The start of the guide time window (30 minutes ago).
    /// Matches `ChannelLibraryViewModel`'s fetch window.
    static func timeWindowStart(relativeTo now: Date = .now) -> Date {
        Calendar.current.date(byAdding: .minute, value: -30, to: now) ?? now
    }

    /// The end of the guide time window (midnight / start of next day).
    /// Matches `ChannelLibraryViewModel`'s fetch window.
    static func timeWindowEnd(relativeTo now: Date = .now) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.startOfDay(for: tomorrow)
    }

    /// The x-position in points for a given date, relative to the time window start.
    static func xPosition(for date: Date, relativeTo start: Date) -> CGFloat {
        let seconds = date.timeIntervalSince(start)
        return CGFloat(seconds / 3600.0) * pointsPerHour
    }

    /// The width in points for a program, clamped to the visible time window.
    static func width(for program: BaseItemDto, in timeRange: ClosedRange<Date>) -> CGFloat {
        guard let startDate = program.startDate,
              let endDate = program.endDate else { return minimumCellWidth }

        let clampedStart = max(startDate, timeRange.lowerBound)
        let clampedEnd = min(endDate, timeRange.upperBound)

        let seconds = clampedEnd.timeIntervalSince(clampedStart)
        let width = CGFloat(seconds / 3600.0) * pointsPerHour

        return max(width, minimumCellWidth)
    }

    /// The x-position of a program's leading edge, clamped to the time window.
    static func xPosition(for program: BaseItemDto, relativeTo start: Date) -> CGFloat {
        guard let startDate = program.startDate else { return 0 }
        let clampedStart = max(startDate, start)
        return xPosition(for: clampedStart, relativeTo: start)
    }

    /// The total width of the guide grid for the given time range.
    static func totalWidth(for timeRange: ClosedRange<Date>) -> CGFloat {
        let seconds = timeRange.upperBound.timeIntervalSince(timeRange.lowerBound)
        return CGFloat(seconds / 3600.0) * pointsPerHour
    }

    /// Generates time marker dates at the given interval within the time range,
    /// snapped to the nearest interval boundary.
    static func timeMarkers(
        from start: Date,
        to end: Date,
        interval: TimeInterval = 1800 // 30 minutes
    ) -> [Date] {
        let calendar = Calendar.current
        let startMinute = calendar.component(.minute, from: start)
        let minuteInterval = Int(interval / 60)

        // Snap to next interval boundary
        let remainder = startMinute % minuteInterval
        let minutesToAdd = remainder == 0 ? 0 : minuteInterval - remainder
        guard let snappedDate = calendar.date(byAdding: .minute, value: minutesToAdd, to: start) else { return [] }

        // Zero out seconds by extracting only date/time components
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: snappedDate)
        guard var marker = calendar.date(from: components) else { return [] }

        var markers: [Date] = []
        while marker <= end {
            markers.append(marker)
            marker = marker.addingTimeInterval(interval)
        }

        return markers
    }
}
