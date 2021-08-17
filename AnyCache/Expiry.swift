import Foundation

public enum Expiry {
    case never
    case seconds(TimeInterval)
    case date(Date)

    public var date: Date {
        switch self {
        case .never:
            // Ref: http://lists.apple.com/archives/cocoa-dev/2005/Apr/msg01833.html
            return Date(timeIntervalSince1970: 60 * 60 * 24 * 365 * 68)
        case .seconds(let seconds):
            return Date().addingTimeInterval(seconds)
        case .date(let date):
            return date
        }
    }

    public var isExpired: Bool {
        return date.timeIntervalSinceNow < 0
    }

    init(from date: Date) {
        if date == Date(timeIntervalSince1970: 60 * 60 * 24 * 365 * 68) {
            self = .never
        } else {
            self = .date(date)
        }
    }
}
