//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

@MainActor
final class SyncPlayTimeSync {

    private struct Sample {
        let offset: Duration
        let ping: Duration
    }

    private let sampleCount = 8
    private let warmupInterval = Duration.milliseconds(250)
    private let interval = Duration.seconds(30)

    private(set) var offset: Duration = .zero
    private(set) var ping: Duration = .zero

    private var samples: [Sample] = []
    private var task: Task<Void, Never>?

    private weak var userSession: UserSession?

    func start(userSession: UserSession) {
        stop()

        self.userSession = userSession

        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                await measure()

                let interval = samples.count < sampleCount ? warmupInterval : self.interval
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil

        samples.removeAll()
        offset = .zero
        ping = .zero
    }

    func serverTime(from date: Date) -> Date {
        date.addingTimeInterval(offset.seconds)
    }

    func localTime(from serverDate: Date) -> Date {
        serverDate.addingTimeInterval(-offset.seconds)
    }

    private func measure() async {
        guard let userSession else { return }

        do {
            let sent = Date.now
            let response = try await userSession.client.send(Paths.getUtcTime)
            let received = Date.now

            guard let serverReceived = response.value.requestReceptionTime,
                  let serverTransmitted = response.value.responseTransmissionTime
            else { return }

            let sample = Sample(
                offset: .seconds(
                    (serverReceived.timeIntervalSince(sent) + serverTransmitted.timeIntervalSince(received)) / 2
                ),
                ping: .seconds(
                    received.timeIntervalSince(sent) - serverTransmitted.timeIntervalSince(serverReceived)
                )
            )

            samples.append(sample)

            if samples.count > sampleCount {
                samples.removeFirst()
            }

            resolve()

            try await userSession.client.send(
                Paths.syncPlayPing(PingRequestDto(ping: Int(ping.seconds * 1000)))
            )
        } catch {
            return
        }
    }

    private func resolve() {
        guard let best = samples.min(by: { $0.ping < $1.ping }) else { return }

        offset = best.offset
        ping = best.ping
    }
}
