import Foundation

enum AppExecutionEventType: String, Codable, CaseIterable {
    case firstLaunch = "first_launch"
    case existingBaseline = "existing_baseline"
    case update
}

enum AppExecutionUpdateChannel: String, Codable, CaseIterable {
    case directDMG = "direct_dmg"
    case homebrew
    case sparkle
    case unknown
}

enum AppExecutionVersion {
    private static let pattern = #"^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:[-+][0-9A-Za-z.-]{1,20})?$"#

    static func normalize(_ value: String?) -> String? {
        guard var candidate = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !candidate.isEmpty
        else {
            return nil
        }

        if candidate.first == "v" || candidate.first == "V" {
            candidate.removeFirst()
        }

        guard !candidate.isEmpty,
              candidate.utf8.count <= 32,
              candidate.range(of: pattern, options: .regularExpression) != nil
        else {
            return nil
        }

        return candidate
    }
}

enum AppExecutionUTCDate {
    static func string(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func isValid(_ value: String) -> Bool {
        guard value.range(
            of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#,
            options: .regularExpression
        ) != nil else {
            return false
        }

        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            return false
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]

        guard let date = calendar.date(from: components) else {
            return false
        }
        return string(for: date) == value
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

struct AppExecutionEvent: Codable, Equatable, Identifiable {
    let eventID: UUID
    let eventType: AppExecutionEventType
    let occurredDate: String
    let fromVersion: String?
    let toVersion: String
    let updateChannel: AppExecutionUpdateChannel

    var id: UUID {
        eventID
    }

    static func make(
        eventID: UUID = UUID(),
        eventType: AppExecutionEventType,
        occurredAt: Date,
        fromVersion: String?,
        toVersion: String,
        updateChannel: AppExecutionUpdateChannel
    ) -> AppExecutionEvent? {
        guard isVersion4(eventID),
              let normalizedToVersion = AppExecutionVersion.normalize(toVersion)
        else {
            return nil
        }

        let normalizedFromVersion = AppExecutionVersion.normalize(fromVersion)
        switch eventType {
        case .update:
            guard let normalizedFromVersion,
                  normalizedFromVersion != normalizedToVersion
            else {
                return nil
            }
        case .firstLaunch, .existingBaseline:
            guard fromVersion == nil else {
                return nil
            }
        }

        return AppExecutionEvent(
            eventID: eventID,
            eventType: eventType,
            occurredDate: AppExecutionUTCDate.string(for: occurredAt),
            fromVersion: normalizedFromVersion,
            toVersion: normalizedToVersion,
            updateChannel: updateChannel
        )
    }

    private init(
        eventID: UUID,
        eventType: AppExecutionEventType,
        occurredDate: String,
        fromVersion: String?,
        toVersion: String,
        updateChannel: AppExecutionUpdateChannel
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.occurredDate = occurredDate
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.updateChannel = updateChannel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventIDString = try container.decode(String.self, forKey: .eventID)
        let eventType = try container.decode(AppExecutionEventType.self, forKey: .eventType)
        let occurredDate = try container.decode(String.self, forKey: .occurredDate)
        let fromVersion = try container.decodeIfPresent(String.self, forKey: .fromVersion)
        let toVersion = try container.decode(String.self, forKey: .toVersion)
        let updateChannel = try container.decode(
            AppExecutionUpdateChannel.self,
            forKey: .updateChannel
        )

        guard let eventID = UUID(uuidString: eventIDString),
              Self.isVersion4(eventID),
              AppExecutionUTCDate.isValid(occurredDate),
              let validated = Self.make(
                eventID: eventID,
                eventType: eventType,
                occurredAt: Date(timeIntervalSince1970: 0),
                fromVersion: fromVersion,
                toVersion: toVersion,
                updateChannel: updateChannel
              )
        else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid app execution event payload"
                )
            )
        }

        self.init(
            eventID: validated.eventID,
            eventType: validated.eventType,
            occurredDate: occurredDate,
            fromVersion: validated.fromVersion,
            toVersion: validated.toVersion,
            updateChannel: validated.updateChannel
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventID.uuidString.lowercased(), forKey: .eventID)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(occurredDate, forKey: .occurredDate)
        try container.encodeIfPresent(fromVersion, forKey: .fromVersion)
        if fromVersion == nil {
            try container.encodeNil(forKey: .fromVersion)
        }
        try container.encode(toVersion, forKey: .toVersion)
        try container.encode(updateChannel, forKey: .updateChannel)
    }

    private static func isVersion4(_ uuid: UUID) -> Bool {
        uuid.uuidString.range(
            of: #"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-4[0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$"#,
            options: .regularExpression
        ) != nil
    }

    private enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case eventType = "event_type"
        case occurredDate = "occurred_date"
        case fromVersion = "from_version"
        case toVersion = "to_version"
        case updateChannel = "update_channel"
    }
}
