import AppKit
import EventKit
import SwiftUI

@MainActor
final class CalendarModule: NotchModule {
    let id = "calendar"
    let title = "Calendar"
    var isEnabled = true

    final class StateBox: ObservableObject {
        @Published var events: [CalEvent] = []
        @Published var weekEvents: [CalEvent] = []
        @Published var accessDenied = false
    }

    private let state = StateBox()
    private let store = EKEventStore()
    private var isRefreshing = false
    private let refreshCoordinator = CalendarRefreshCoordinator()

    func collapsedView() -> AnyView? {
        nil
    }

    func expandedView() -> AnyView? {
        AnyView(CalendarBridge(box: state, onGrantAccess: openCalendarSettings))
    }

    func dashboardTile() -> AnyView? {
        AnyView(CalendarDashboardBridge(box: state, onGrantAccess: openCalendarSettings))
    }

    func wideBarView() -> AnyView? {
        AnyView(CalendarWideBarBridge(box: state))
    }

    func activate() {
        refreshCoordinator.activate { [weak self] in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        Task { @MainActor in await refresh() }
    }

    func deactivate() {
        refreshCoordinator.deactivate()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else {
            if !state.accessDenied { state.accessDenied = true }
            if !state.events.isEmpty { state.events = [] }
            if !state.weekEvents.isEmpty { state.weekEvents = [] }
            return
        }

        let calendar = Calendar.current
        let now = Date()
        guard let week = CalendarAgendaRange.week.interval(containing: now, calendar: calendar),
              let today = CalendarAgendaRange.today.interval(containing: now, calendar: calendar) else { return }
        let start = week.start
        let end = week.end

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let mapped = store.events(matching: predicate).map { event in
            CalEvent(title: event.title ?? "Untitled",
                     start: event.startDate ?? start,
                     colorHex: nil, end: event.endDate, isAllDay: event.isAllDay)
        }.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            return (lhs.end ?? lhs.start) < (rhs.end ?? rhs.start)
        }

        if state.accessDenied { state.accessDenied = false }
        if state.weekEvents != mapped { state.weekEvents = mapped }
        let upcoming = CalendarFormat.upcoming(mapped.filter { CalendarFormat.overlaps($0, interval: today) },
                                               now: now, limit: 4)
        if state.events != upcoming { state.events = upcoming }
    }
    private func openCalendarSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct CalendarBridge: View {
    @ObservedObject var box: CalendarModule.StateBox
    let onGrantAccess: () -> Void

    var body: some View {
        CalendarExpandedView(events: box.events,
                             accessDenied: box.accessDenied,
                             onGrantAccess: onGrantAccess)
    }
}

private struct CalendarDashboardBridge: View {
    @ObservedObject var box: CalendarModule.StateBox
    let onGrantAccess: () -> Void

    var body: some View {
        CalendarDashboardTile(events: box.weekEvents,
                              accessDenied: box.accessDenied,
                              onGrantAccess: onGrantAccess)
    }
}

private struct CalendarWideBarBridge: View {
    @ObservedObject var box: CalendarModule.StateBox

    var body: some View {
        CalendarWideBar(events: box.events, accessDenied: box.accessDenied)
    }
}
