import Foundation

public struct TrafficMonitorConfiguration: Equatable, Sendable {
    public var historyWindow: Duration
    public var reconnectDelay: Duration
    public var initialConnectDelay: Duration
    public var maxPoints: Int

    public init(
        historyWindow: Duration = .seconds(10 * 60),
        reconnectDelay: Duration = .seconds(1),
        initialConnectDelay: Duration = .milliseconds(300),
        maxPoints: Int = 600
    ) {
        self.historyWindow = historyWindow
        self.reconnectDelay = reconnectDelay
        self.initialConnectDelay = initialConnectDelay
        self.maxPoints = max(1, maxPoints)
    }

    public static let `default` = TrafficMonitorConfiguration()
}

/// Collects Mihomo `/traffic`, `/memory`, and `/connections` totals into a UI snapshot.
public actor TrafficMonitor {
    private let webSocket: any MihomoWebSocketStreaming
    private let configuration: TrafficMonitorConfiguration
    private var apiConfiguration: MihomoAPIConfiguration?

    private var trafficTask: Task<Void, Never>?
    private var memoryTask: Task<Void, Never>?
    private var totalsTask: Task<Void, Never>?
    private var isRunning = false
    private var generation = 0

    private var latestUp: UInt64 = 0
    private var latestDown: UInt64 = 0
    private var latestUploadTotal: UInt64 = 0
    private var latestDownloadTotal: UInt64 = 0
    private var latestMemory: UInt64 = 0
    private var points: [TrafficSpeedSample] = []
    private var lastUpdated: Date?
    private var trafficLive = false
    private var memoryLive = false
    private var totalsLive = false

    private var continuations: [UUID: AsyncStream<TrafficSnapshot>.Continuation] = [:]

    public init(
        webSocket: any MihomoWebSocketStreaming = MihomoWebSocketClient(),
        configuration: TrafficMonitorConfiguration = .default
    ) {
        self.webSocket = webSocket
        self.configuration = configuration
    }

    deinit {
        trafficTask?.cancel()
        memoryTask?.cancel()
        totalsTask?.cancel()
    }

    nonisolated public func snapshots() -> AsyncStream<TrafficSnapshot> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.registerContinuation(id: id, continuation: continuation) }
            continuation.onTermination = { @Sendable _ in
                Task { await self.unregisterContinuation(id: id) }
            }
        }
    }

    public func currentSnapshot() -> TrafficSnapshot {
        makeSnapshot()
    }

    public func start(configuration api: MihomoAPIConfiguration) {
        if isRunning, apiConfiguration == api {
            return
        }
        stopInternal(resetSnapshot: false)
        apiConfiguration = api
        isRunning = true
        generation += 1
        let generation = self.generation

        trafficTask = Task { [weak self] in
            await self?.runTrafficLoop(generation: generation)
        }
        memoryTask = Task { [weak self] in
            await self?.runMemoryLoop(generation: generation)
        }
        totalsTask = Task { [weak self] in
            await self?.runTotalsLoop(generation: generation)
        }
        publish()
    }

    public func stop() {
        stopInternal(resetSnapshot: true)
        publish()
    }

    private func stopInternal(resetSnapshot: Bool) {
        isRunning = false
        generation += 1
        trafficTask?.cancel()
        memoryTask?.cancel()
        totalsTask?.cancel()
        trafficTask = nil
        memoryTask = nil
        totalsTask = nil
        trafficLive = false
        memoryLive = false
        totalsLive = false
        if resetSnapshot {
            latestUp = 0
            latestDown = 0
            latestUploadTotal = 0
            latestDownloadTotal = 0
            latestMemory = 0
            points = []
            lastUpdated = nil
        }
    }

    private func registerContinuation(
        id: UUID,
        continuation: AsyncStream<TrafficSnapshot>.Continuation
    ) {
        continuations[id] = continuation
        continuation.yield(makeSnapshot())
    }

    private func unregisterContinuation(id: UUID) {
        continuations[id] = nil
    }

    private func publish() {
        let snapshot = makeSnapshot()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func makeSnapshot() -> TrafficSnapshot {
        TrafficSnapshot(
            up: latestUp,
            down: latestDown,
            uploadTotal: latestUploadTotal,
            downloadTotal: latestDownloadTotal,
            memoryInUse: latestMemory,
            points: points,
            isLive: isRunning && (trafficLive || memoryLive || totalsLive),
            lastUpdated: lastUpdated
        )
    }

    private func runTrafficLoop(generation: Int) async {
        await runStreamLoop(generation: generation, path: "/traffic") { data in
            let sample = try MihomoAPIDecoder.decodeTraffic(data)
            applyTraffic(sample)
        } onStreamEnded: {
            trafficLive = false
        } onStreamFailed: {
            trafficLive = false
            latestUp = 0
            latestDown = 0
        }
    }

    private func runMemoryLoop(generation: Int) async {
        await runStreamLoop(generation: generation, path: "/memory") { data in
            let memory = try MihomoAPIDecoder.decodeMemory(data)
            applyMemory(memory)
        } onStreamEnded: {
            memoryLive = false
        } onStreamFailed: {
            memoryLive = false
        }
    }

    private func runTotalsLoop(generation: Int) async {
        await runStreamLoop(generation: generation, path: "/connections") { data in
            let totals = try MihomoAPIDecoder.decodeTrafficTotals(data)
            applyTotals(totals)
        } onStreamEnded: {
            totalsLive = false
        } onStreamFailed: {
            totalsLive = false
        }
    }

    private func runStreamLoop(
        generation: Int,
        path: String,
        onMessage: (Data) throws -> Void,
        onStreamEnded: () -> Void,
        onStreamFailed: () -> Void
    ) async {
        if configuration.initialConnectDelay > .zero {
            try? await Task.sleep(for: configuration.initialConnectDelay)
        }
        guard isRunning, self.generation == generation else { return }

        while isRunning, self.generation == generation, !Task.isCancelled {
            guard let api = apiConfiguration else { return }
            let stream = webSocket.stream(configuration: api, path: path)
            do {
                for try await data in stream {
                    guard isRunning, self.generation == generation else { return }
                    try onMessage(data)
                }
                onStreamEnded()
                publish()
            } catch is CancellationError {
                return
            } catch MihomoAPIClientError.cancelled {
                return
            } catch {
                onStreamFailed()
                publish()
            }

            guard isRunning, self.generation == generation else { return }
            try? await Task.sleep(for: configuration.reconnectDelay)
        }
    }

    private func applyTraffic(_ sample: TrafficSpeedSample) {
        latestUp = sample.up
        latestDown = sample.down
        trafficLive = true
        lastUpdated = sample.timestamp
        points.append(sample)
        trimPoints(now: sample.timestamp)
        publish()
    }

    private func applyMemory(_ memory: MihomoMemoryUsage) {
        latestMemory = memory.inuse
        memoryLive = true
        lastUpdated = Date()
        publish()
    }

    private func applyTotals(_ totals: MihomoTrafficTotals) {
        latestUploadTotal = totals.uploadTotal
        latestDownloadTotal = totals.downloadTotal
        totalsLive = true
        lastUpdated = Date()
        publish()
    }

    private func trimPoints(now: Date) {
        let cutoff = now.addingTimeInterval(-historyWindowSeconds)
        if let firstKeep = points.firstIndex(where: { $0.timestamp >= cutoff }) {
            if firstKeep > 0 {
                points.removeFirst(firstKeep)
            }
        } else if !points.isEmpty {
            points.removeAll(keepingCapacity: true)
        }
        if points.count > configuration.maxPoints {
            points.removeFirst(points.count - configuration.maxPoints)
        }
    }

    private var historyWindowSeconds: TimeInterval {
        let components = configuration.historyWindow.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

// MARK: - Test helpers

extension TrafficMonitor {
    /// Injects a traffic sample without going through a WebSocket (tests only).
    public func testApplyTraffic(up: UInt64, down: UInt64, at date: Date = Date()) {
        applyTraffic(TrafficSpeedSample(up: up, down: down, timestamp: date))
    }

    /// Injects memory usage without going through a WebSocket (tests only).
    public func testApplyMemory(inuse: UInt64) {
        applyMemory(MihomoMemoryUsage(inuse: inuse))
    }

    /// Injects cumulative totals without going through a WebSocket (tests only).
    public func testApplyTotals(uploadTotal: UInt64, downloadTotal: UInt64) {
        applyTotals(MihomoTrafficTotals(uploadTotal: uploadTotal, downloadTotal: downloadTotal))
    }
}
