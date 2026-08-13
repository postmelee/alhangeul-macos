import XCTest

final class AppExecutionEventTests: XCTestCase {
    private let eventID = UUID(uuidString: "12345678-1234-4abc-8def-1234567890ab")!

    func testUpdatePayloadEncodesOnlyCollectorContractKeys() throws {
        let event = try XCTUnwrap(
            AppExecutionEvent.make(
                eventID: eventID,
                eventType: .update,
                occurredAt: date("2026-08-03T23:59:59Z"),
                fromVersion: "v0.1.8",
                toVersion: "0.1.9",
                updateChannel: .sparkle
            )
        )

        let data = try JSONEncoder().encode(event)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(
            Set(object.keys),
            Set([
                "event_id",
                "event_type",
                "occurred_date",
                "from_version",
                "to_version",
                "update_channel",
            ])
        )
        XCTAssertEqual(object["event_id"] as? String, eventID.uuidString.lowercased())
        XCTAssertEqual(object["event_type"] as? String, "update")
        XCTAssertEqual(object["occurred_date"] as? String, "2026-08-03")
        XCTAssertEqual(object["from_version"] as? String, "0.1.8")
        XCTAssertEqual(object["to_version"] as? String, "0.1.9")
        XCTAssertEqual(object["update_channel"] as? String, "sparkle")
    }

    func testBaselinePayloadEncodesNullPreviousVersion() throws {
        let event = try XCTUnwrap(
            AppExecutionEvent.make(
                eventID: eventID,
                eventType: .existingBaseline,
                occurredAt: date("2026-08-03T00:00:00Z"),
                fromVersion: nil,
                toVersion: "0.1.9",
                updateChannel: .unknown
            )
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(event))
                as? [String: Any]
        )

        XCTAssertTrue(object["from_version"] is NSNull)
    }

    func testVersionNormalizationMatchesCollectorContract() {
        XCTAssertEqual(AppExecutionVersion.normalize(" v0.1.9 "), "0.1.9")
        XCTAssertEqual(AppExecutionVersion.normalize("1.2.3-beta.1"), "1.2.3-beta.1")
        XCTAssertEqual(AppExecutionVersion.normalize("1.2.3+build.7"), "1.2.3+build.7")
        XCTAssertNil(AppExecutionVersion.normalize("01.2.3"))
        XCTAssertNil(AppExecutionVersion.normalize("1.2"))
        XCTAssertNil(AppExecutionVersion.normalize("1.2.3_unsupported"))
        XCTAssertNil(AppExecutionVersion.normalize(String(repeating: "1", count: 33)))
    }

    func testEventValidationRejectsWrongVersionAndEventShapes() {
        XCTAssertNil(
            AppExecutionEvent.make(
                eventID: eventID,
                eventType: .update,
                occurredAt: Date(),
                fromVersion: "0.1.9",
                toVersion: "0.1.9",
                updateChannel: .unknown
            )
        )
        XCTAssertNil(
            AppExecutionEvent.make(
                eventID: eventID,
                eventType: .firstLaunch,
                occurredAt: Date(),
                fromVersion: "0.1.8",
                toVersion: "0.1.9",
                updateChannel: .unknown
            )
        )
        XCTAssertNil(
            AppExecutionEvent.make(
                eventID: UUID(uuidString: "12345678-1234-1abc-8def-1234567890ab")!,
                eventType: .firstLaunch,
                occurredAt: Date(),
                fromVersion: nil,
                toVersion: "0.1.9",
                updateChannel: .unknown
            )
        )
    }

    func testUTCDateIgnoresLocalDayBoundary() {
        XCTAssertEqual(
            AppExecutionUTCDate.string(for: date("2026-08-03T23:59:59Z")),
            "2026-08-03"
        )
        XCTAssertTrue(AppExecutionUTCDate.isValid("2024-02-29"))
        XCTAssertFalse(AppExecutionUTCDate.isValid("2025-02-29"))
        XCTAssertFalse(AppExecutionUTCDate.isValid("2026-13-01"))
    }

    func testDecodingRejectsInvalidStoredPayload() throws {
        let invalidPayload = #"{"event_id":"12345678-1234-4abc-8def-1234567890ab","event_type":"update","occurred_date":"2026-02-29","from_version":"0.1.8","to_version":"0.1.9","update_channel":"sparkle"}"#

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                AppExecutionEvent.self,
                from: Data(invalidPayload.utf8)
            )
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
