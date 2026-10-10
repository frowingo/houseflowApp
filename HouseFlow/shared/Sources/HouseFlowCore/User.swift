import Foundation

public struct User: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    /// The server-assigned user ID (nil for locally created / preview users).
    public let apiId: String?
    public let name: String
    public let firstName: String
    public let lastName: String
    public let initials: String
    public let points: Int
    public let imageUrl: String?

    public init(
        id: String? = nil,
        firstName: String,
        lastName: String,
        apiId: String? = nil,
        points: Int = 0,
        imageUrl: String? = nil
    ) {
        self.id = apiId ?? id ?? "\(firstName)-\(lastName)".lowercased()
        self.apiId = apiId
        self.firstName = firstName
        self.lastName = lastName
        self.name = "\(firstName) \(lastName)"
        self.points = points
        self.initials = String(firstName.prefix(1)) + String(lastName.prefix(1))
        self.imageUrl = imageUrl
    }

    /// Convenience initializer for preview/sample data where only a full name is available.
    public init(
        id: String? = nil,
        name: String,
        points: Int = 0,
        imageUrl: String? = nil
    ) {
        let components = name.split(separator: " ", maxSplits: 1)
        self.id = id ?? name.lowercased()
        self.apiId = nil
        self.firstName = components.first.map(String.init) ?? name
        self.lastName = components.dropFirst().first.map(String.init) ?? ""
        self.name = name
        self.points = points
        self.imageUrl = imageUrl
        if components.count >= 2 {
            self.initials = String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else {
            self.initials = String(name.prefix(2))
        }
    }
}
