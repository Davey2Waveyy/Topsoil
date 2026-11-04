import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class SystemModule: NotchModule {
    let id = "system"
    let title = "Battery & System"
    var isEnabled = true

    final class StateBox: ObservableObject {
        @Published var sample = SystemSample(
            batteryPercent: nil,
            isCharging: false,
            cpuPercent: 0,
            ramUsedBytes: 0
        )
    }

    private let state = StateBox()
    private var timer: Timer?

    // Battery alert state — track last seen values to fire notifications only on crossing.
    private var lastAlertedLow = false
    private var lastAlertedHigh = false

    func collapsedView() -> AnyView? {
        nil
    }

    func expandedView() -> AnyView? {
        AnyView(SystemModuleBridge(box: state))
    }

    func dashboardTile() -> AnyView? {
        AnyView(SystemDashboardBridge(box: state))
    }

    func wideBarView() -> AnyView? {
        AnyView(SystemWideBarBridge(box: state))
    }

    func activate() {
        refreshTimer()
        Task { @MainActor in
            await refresh()
        }
    }

    func deactivate() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async {
        let sample = SystemSampler.sample()
        state.sample = sample
        checkBatteryAlerts(sample)
    }

    private func refreshTimer() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        timer?.tolerance = EnergyRefreshPolicy.tolerance(for: 15)
    }

    // MARK: - Battery alerts

    private func checkBatteryAlerts(_ sample: SystemSample) {
        guard let pct = sample.batteryPercent else { return }

        let isLow = pct <= 20 && !sample.isCharging
        if isLow && !lastAlertedLow {
            lastAlertedLow = true
            sendNotification(title: "Battery Low (\(pct)%)",
                             body: "Plug in to avoid losing work.",
                             id: "battery-low")
        } else if !isLow {
            lastAlertedLow = false
        }

        let isHigh = pct >= 80 && sample.isCharging
        if isHigh && !lastAlertedHigh {
            lastAlertedHigh = true
            sendNotification(title: "Battery at \(pct)%",
                             body: "You can safely unplug now.",
                             id: "battery-high")
        } else if !isHigh {
            lastAlertedHigh = false
        }
    }

    private func sendNotification(title: String, body: String, id: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

private struct SystemModuleBridge: View {
    @ObservedObject var box: SystemModule.StateBox

    var body: some View {
        SystemExpandedView(sample: box.sample)
    }
}

private struct SystemDashboardBridge: View {
    @ObservedObject var box: SystemModule.StateBox

    var body: some View {
        SystemDashboardTile(sample: box.sample)
    }
}

private struct SystemWideBarBridge: View {
    @ObservedObject var box: SystemModule.StateBox

    var body: some View {
        SystemWideBar(sample: box.sample)
    }
}
