import Foundation

enum HouseFlowDateFormatter {
    private static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func parseAPIDate(_ value: String) -> Date? {
        isoWithFractionalSeconds.date(from: value) ?? isoInternetDateTime.date(from: value)
    }

    static func apiString(from date: Date) -> String {
        isoInternetDateTime.string(from: date)
    }

    static func displayDate(from value: String?) -> String {
        guard let value, !value.isEmpty, let date = parseAPIDate(value) else { return "—" }
        return displayDateFormatter.string(from: date)
    }

    static func dueLabel(from value: String) -> String {
        guard let date = parseAPIDate(value) else { return "Upcoming" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if date < Date() { return "Overdue" }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) { return "This week" }
        return "Upcoming"
    }
}
