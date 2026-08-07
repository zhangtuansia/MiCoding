import Foundation

@MainActor
final class RemoteGestureEngine {
    var holdMilliseconds = 350
    var doubleTapMilliseconds = 250
    var hasBinding: ((String, RemoteTrigger) -> Bool)?
    var onResolvedTrigger: ((ResolvedRemoteTrigger) -> Void)?

    private struct KeyState {
        var isDown = false
        var holdFired = false
        var waitingForSecondTap = false
        var sequence = 0
    }

    private var states: [String: KeyState] = [:]

    func handle(_ event: RemoteInputEvent) {
        switch event.phase {
        case .began:
            handleDown(slotID: event.slotID)
        case .ended:
            handleUp(slotID: event.slotID)
        }
    }

    func reset() {
        states.removeAll()
    }

    private func handleDown(slotID: String) {
        var state = states[slotID] ?? KeyState()
        guard !state.isDown else { return }

        if state.waitingForSecondTap,
           hasBinding?(slotID, .doubleTap) == true {
            state.sequence += 1
            state.waitingForSecondTap = false
            state.isDown = true
            state.holdFired = true
            states[slotID] = state
            onResolvedTrigger?(ResolvedRemoteTrigger(slotID: slotID, trigger: .doubleTap))
            return
        }

        state.isDown = true
        state.holdFired = false
        state.sequence += 1
        let sequence = state.sequence
        states[slotID] = state

        guard hasBinding?(slotID, .hold) == true else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(0, holdMilliseconds))) { [weak self] in
            guard let self else { return }
            var latest = self.states[slotID] ?? KeyState()
            guard latest.isDown, latest.sequence == sequence, !latest.holdFired else { return }
            latest.holdFired = true
            self.states[slotID] = latest
            self.onResolvedTrigger?(ResolvedRemoteTrigger(slotID: slotID, trigger: .hold))
        }
    }

    private func handleUp(slotID: String) {
        var state = states[slotID] ?? KeyState()
        guard state.isDown else { return }
        state.isDown = false
        state.sequence += 1

        if state.holdFired {
            state.holdFired = false
            states[slotID] = state
            return
        }

        guard hasBinding?(slotID, .doubleTap) == true,
              doubleTapMilliseconds > 0 else {
            states[slotID] = state
            onResolvedTrigger?(ResolvedRemoteTrigger(slotID: slotID, trigger: .tap))
            return
        }

        state.waitingForSecondTap = true
        let sequence = state.sequence
        states[slotID] = state
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(doubleTapMilliseconds)) { [weak self] in
            guard let self else { return }
            var latest = self.states[slotID] ?? KeyState()
            guard latest.waitingForSecondTap, latest.sequence == sequence else { return }
            latest.waitingForSecondTap = false
            self.states[slotID] = latest
            self.onResolvedTrigger?(ResolvedRemoteTrigger(slotID: slotID, trigger: .tap))
        }
    }
}
