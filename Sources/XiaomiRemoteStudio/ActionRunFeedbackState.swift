struct ActionRunFeedbackState: Equatable {
    enum Phase: Equatable {
        case idle
        case running
        case succeeded
    }

    private(set) var phase: Phase = .idle

    var isRunning: Bool {
        phase == .running
    }

    var didSucceed: Bool {
        phase == .succeeded
    }

    var canRun: Bool {
        phase == .idle
    }

    @discardableResult
    mutating func begin() -> Bool {
        guard canRun else { return false }
        phase = .running
        return true
    }

    mutating func complete(with result: ActionExecutionResult) {
        guard isRunning else { return }
        phase = result == .success ? .succeeded : .idle
    }

    mutating func reset() {
        phase = .idle
    }
}
