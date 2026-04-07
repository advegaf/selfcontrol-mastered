import SwiftUI

// MARK: - BlockTimerCoordinator

/// ViewModifier that handles timer startup, configuration-changed notifications,
/// retry-on-appear, and the addingBlock safety timeout.
///
/// Shared between MenuBarContentView and UnifiedRootView to avoid duplicating
/// the same coordination logic in both places.
@available(macOS 16.0, *)
struct BlockTimerCoordinator: ViewModifier {

    @Environment(TimerViewModel.self) private var timer
    @Environment(BlockStateViewModel.self) private var blockState

    private let configNotification = NotificationCenter.default.publisher(
        for: NSNotification.Name("SCConfigurationChangedNotification")
    )
    private let distributedConfigNotification = DistributedNotificationCenter.default().publisher(
        for: NSNotification.Name("SCConfigurationChangedNotification")
    )

    func body(content: Content) -> some View {
        content
            .onAppear {
                tryStartTimerIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tryStartTimerIfNeeded() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { tryStartTimerIfNeeded() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { tryStartTimerIfNeeded() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { tryStartTimerIfNeeded() }
            }
            .onReceive(configNotification) { _ in
                tryStartTimerIfNeeded()
            }
            .onReceive(distributedConfigNotification) { _ in
                tryStartTimerIfNeeded()
            }
            .onChange(of: blockState.blockEndDate) { _, newEndDate in
                // Reconcile the running countdown against the persistent
                // BlockEndDate. Fires after the daemon writes a new end date
                // and broadcasts SCConfigurationChangedNotification (e.g. after
                // a successful + extend) — or when an optimistic extend got
                // clamped/rejected and the pill needs to snap back. If the
                // authoritative value is earlier than what we were optimistically
                // showing, shake the pill so the failure is visible.
                guard timer.hasStarted, let newEndDate else { return }
                let didShrink = timer.reconcile(to: newEndDate)
                if didShrink {
                    NotificationCenter.default.post(
                        name: .selfControlPillShake,
                        object: nil
                    )
                }
            }
            .onChange(of: blockState.addingBlock) { _, adding in
                if adding {
                    // Safety timeout: if addingBlock stays true for 30s, the XPC
                    // chain probably failed. Reset so the user can try again.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        if blockState.addingBlock {
                            if let appController = NSApp.delegate as? AppController {
                                appController.addingBlock = false
                            }
                            blockState.refresh()
                        }
                    }
                }
            }
    }

    private func tryStartTimerIfNeeded() {
        SCSettings.shared().reload()
        blockState.refresh()
        if !timer.hasStarted, blockState.blockIsActive, let endDate = blockState.blockEndDate {
            timer.start(endDate: endDate)
        }
    }
}

@available(macOS 16.0, *)
extension View {
    func blockTimerCoordination() -> some View {
        modifier(BlockTimerCoordinator())
    }
}
