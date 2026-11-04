import SwiftUI

struct CalendarExpandedView: View {
    let events: [CalEvent]
    let accessDenied: Bool
    let onGrantAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(CalendarFormat.dayHeader(Date(), calendar: .current))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)

            if accessDenied {
                Button(action: onGrantAccess) {
                    Text("Grant Calendar access")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 1))
                }
                .buttonStyle(.plain)
            } else if events.isEmpty {
                Text("Nothing left today")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ForEach(events.indices, id: \.self) { index in
                    let event = events[index]
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.35, green: 0.78, blue: 1))
                            .frame(width: 5, height: 5)
                        Text(CalendarFormat.eventLabel(event, now: Date(), calendar: .current))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(event.title)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .font(.system(size: 10))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Agenda widget for the dashboard layout.
struct CalendarDashboardTile: View {
    let events: [CalEvent]
    let accessDenied: Bool
    let onGrantAccess: () -> Void
    @AppStorage("calendar.agendaRange") private var range: CalendarAgendaRange = .today
    @Environment(\.notchTokens) private var tokens

    var body: some View {
        let now = Date()
        let days = CalendarFormat.agenda(events, range: range, now: now, calendar: .current)
        VStack(alignment: .leading, spacing: 8) {
            TileHeader(title: "Calendar", systemImage: "calendar")
            Picker("Agenda range", selection: $range) {
                Text("Today").tag(CalendarAgendaRange.today)
                Text("Week").tag(CalendarAgendaRange.week)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Calendar agenda range")
            if accessDenied {
                Button("Grant Calendar access", action: onGrantAccess)
                    .font(tokens.bodyFont)
                    .tint(tokens.accent)
            } else if days.isEmpty {
                Text(range == .today ? "No events today" : "No events this week")
                    .font(tokens.bodyFont)
                    .foregroundStyle(tokens.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(days) { day in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(CalendarFormat.dayHeader(day.date, calendar: .current))
                                    .font(tokens.captionFont)
                                    .foregroundStyle(tokens.textSecondary)
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(day.events.indices, id: \.self) { index in
                                    let event = day.events[index]
                                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                                        Text(CalendarFormat.eventLabel(event, now: now, calendar: .current))
                                            .font(tokens.captionFont)
                                            .foregroundStyle(tokens.textSecondary)
                                            .frame(width: 42, alignment: .leading)
                                        Text(event.title)
                                            .font(tokens.bodyFont)
                                            .foregroundStyle(tokens.textPrimary)
                                            .lineLimit(2)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityLabel(range == .today ? "Today's events" : "This week's events")
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Next-event summary for the wide bar.
struct CalendarWideBar: View {
    let events: [CalEvent]
    let accessDenied: Bool

    var body: some View {
        if accessDenied {
            WideBarItem(systemImage: "calendar.badge.exclamationmark", text: "Calendar off")
        } else if let next = events.first {
            WideBarItem(systemImage: "calendar",
                        text: "\(CalendarFormat.eventLabel(next, now: Date(), calendar: .current))  \(next.title)")
        } else {
            WideBarItem(systemImage: "calendar", text: "No more today")
        }
    }
}
