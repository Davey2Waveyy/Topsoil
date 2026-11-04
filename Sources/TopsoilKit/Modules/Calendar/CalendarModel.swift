import Foundation

/// A calendar event reduced to what the notch needs to display.
public struct CalEvent: Equatable, Sendable {
    public var title: String
    public var start: Date
    public var colorHex: String?
    public var end: Date?
    public var isAllDay: Bool

    public init(title: String, start: Date, colorHex: String?, end: Date? = nil, isAllDay: Bool = false) {
        self.title = title
        self.start = start
        self.colorHex = colorHex
        self.end = end
        self.isAllDay = isAllDay
    }
}

public enum CalendarAgendaRange: String, CaseIterable, Sendable {
    case today, week

    public func interval(containing date: Date, calendar: Calendar) -> DateInterval? {
        calendar.dateInterval(of: self == .today ? .day : .weekOfYear, for: date)
    }
}

public struct CalendarAgendaDay: Identifiable, Equatable, Sendable {
    public var date: Date
    public var events: [CalEvent]
    public var id: Date { date }
}

/// Pure formatting/filtering for calendar events (no EventKit, so it's testable).
public enum CalendarFormat {
    /// 24-hour zero-padded time, e.g. "09:05".
    public static func timeLabel(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    /// Day header, e.g. "Mon, Jun 22".
    public static func dayHeader(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    public static func eventLabel(_ event: CalEvent, now: Date, calendar: Calendar) -> String {
        if event.isAllDay { return "All day" }
        if event.start < now, let end = event.end, end > now { return "Now" }
        return timeLabel(event.start, calendar: calendar)
    }

    /// EventKit end dates are exclusive, including all-day and multi-day events.
    public static func overlaps(_ event: CalEvent, interval: DateInterval) -> Bool {
        event.start < interval.end && (event.end.map { $0 > interval.start } ?? (event.start >= interval.start))
    }

    public static func agenda(_ events: [CalEvent], range: CalendarAgendaRange,
                              now: Date, calendar: Calendar) -> [CalendarAgendaDay] {
        guard let interval = range.interval(containing: now, calendar: calendar) else { return [] }
        var days: [CalendarAgendaDay] = []
        var day = interval.start
        while day < interval.end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let dayInterval = DateInterval(start: day, end: next)
            let matching = events.filter { overlaps($0, interval: dayInterval) }
                .sorted { lhs, rhs in
                    if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                    return lhs.start < rhs.start
                }
            if !matching.isEmpty { days.append(CalendarAgendaDay(date: day, events: matching)) }
            day = next
        }
        return days
    }

    /// Events at or after `now`, soonest first, capped at `limit`.
    public static func upcoming(_ events: [CalEvent], now: Date, limit: Int) -> [CalEvent] {
        events
            .filter { $0.start >= now || ($0.end.map { $0 > now } ?? false) }
            .sorted { $0.start < $1.start }
            .prefix(max(0, limit))
            .map { $0 }
    }
}
