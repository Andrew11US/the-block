import Foundation

enum AuctionStatus: Equatable {
    case upcoming, live, ended
}

struct AuctionSchedule: Equatable, Sendable {
    let start: Date
    let end: Date

    init?(start: String, end: String, timezone: String) {
        guard let zone = TimeZone(identifier: timezone) else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.timeZone = zone
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        parser.isLenient = false
        guard let startDate = parser.date(from: start), parser.string(from: startDate) == start,
              let endDate = parser.date(from: end), parser.string(from: endDate) == end,
              endDate > startDate else { return nil }
        self.start = startDate
        self.end = endDate
    }

    init?(vehicle: Vehicle) {
        guard let schedule = vehicle.auctionSchedule else { return nil }
        self = schedule
    }

    /// Only these dates can change status; countdown ticks must not invalidate lists.
    var transitionDates: [Date] { [start, end] }

    func timelineDates(from now: Date) -> [Date] {
        [now] + transitionDates.filter { $0 > now }
    }

    func status(at now: Date) -> AuctionStatus {
        if now < start { return .upcoming }
        return now < end ? .live : .ended
    }
}
