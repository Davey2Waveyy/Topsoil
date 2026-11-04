import Foundation
import TopsoilKit

func calendarFormatTests() {
    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    func at(_ hour: Int, _ minute: Int) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 6, day: 22, hour: hour, minute: minute))!
    }

    test("calendar: upcoming filters past events and limits count") {
        let now = at(12, 0)
        let events = [
            CalEvent(title: "past", start: at(9, 0), colorHex: nil),
            CalEvent(title: "soon", start: at(13, 0), colorHex: nil),
            CalEvent(title: "later", start: at(16, 0), colorHex: nil),
            CalEvent(title: "evening", start: at(19, 0), colorHex: nil),
        ]
        let upcoming = CalendarFormat.upcoming(events, now: now, limit: 2)
        expect(upcoming.map(\.title) == ["soon", "later"], "future-only, soonest-first, capped at 2")
    }

    test("calendar: upcoming sorts unordered input") {
        let now = at(8, 0)
        let events = [
            CalEvent(title: "b", start: at(16, 0), colorHex: nil),
            CalEvent(title: "a", start: at(10, 0), colorHex: nil),
        ]
        expect(CalendarFormat.upcoming(events, now: now, limit: 5).map(\.title) == ["a", "b"], "sorted by start")
    }

    test("calendar: time label is zero-padded 24-hour") {
        expect(CalendarFormat.timeLabel(at(9, 5), calendar: utc) == "09:05", "morning padded")
        expect(CalendarFormat.timeLabel(at(13, 30), calendar: utc) == "13:30", "afternoon 24h")
    }

    test("calendar: day header is weekday and month/day") {
        expect(CalendarFormat.dayHeader(at(9, 0), calendar: utc) == "Mon, Jun 22", "header format")
    }
    test("calendar: week honors first weekday and crosses year boundary") {
        var calendar = utc
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let interval = CalendarAgendaRange.week.interval(containing: date, calendar: calendar)!
        expectEqual(calendar.component(.day, from: interval.start), 29, "week starts in December")
        expectEqual(calendar.component(.month, from: interval.start), 12, "previous month")
        expectEqual(calendar.component(.day, from: interval.end), 5, "exclusive next Monday")
    }

    test("calendar: ongoing and all-day events survive upcoming filtering") {
        let ongoing = CalEvent(title: "Meeting", start: at(11, 0), colorHex: nil, end: at(13, 0))
        let allDay = CalEvent(title: "Holiday", start: at(0, 0), colorHex: nil,
                              end: utc.date(byAdding: .day, value: 1, to: at(0, 0)), isAllDay: true)
        let ended = CalEvent(title: "Ended", start: at(10, 0), colorHex: nil, end: at(12, 0))
        expectEqual(CalendarFormat.upcoming([ongoing, ended, allDay], now: at(12, 0), limit: 4).count, 2,
                    "exclude ended events but retain ongoing and all-day")
        expectEqual(CalendarFormat.eventLabel(ongoing, now: at(12, 0), calendar: utc), "Now", "ongoing label")
        expectEqual(CalendarFormat.eventLabel(allDay, now: at(12, 0), calendar: utc), "All day", "all-day label")
    }

    test("calendar: agenda repeats multi-day events without including exclusive end day") {
        let start = at(0, 0)
        let end = utc.date(byAdding: .day, value: 2, to: start)!
        let event = CalEvent(title: "Trip", start: start, colorHex: nil, end: end, isAllDay: true)
        let days = CalendarFormat.agenda([event], range: .week, now: at(12, 0), calendar: utc)
        expectEqual(days.count, 2, "shown on each occupied day only")
    }

    test("calendar: today follows local DST day boundaries") {
        var calendar = utc
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        let interval = CalendarAgendaRange.today.interval(containing: date, calendar: calendar)!
        expectEqual(interval.duration, 23 * 60 * 60, "spring-forward day is 23 hours")
        let boundary = CalEvent(title: "Tomorrow", start: interval.end, colorHex: nil)
        expect(!CalendarFormat.overlaps(boundary, interval: interval), "next midnight is excluded")
    }

}
