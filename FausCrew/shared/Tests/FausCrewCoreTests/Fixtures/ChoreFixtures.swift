import Foundation

enum ChoreFixtures {
    static let responseWithMixedISOStringsAndNullOptionals = Data(
        """
        {
          "id": "chore-1",
          "title": "Wash dishes",
          "description": "Kitchen",
          "houseId": "house-1",
          "houseOwnerId": "user-1",
          "assignedTo": "user-2",
          "dueDate": "2026-10-12T18:30:00.123Z",
          "isCompleted": false,
          "isRecurring": true,
          "level": 20,
          "recurringInterval": 7,
          "status": 2,
          "createdOn": "2026-10-10T09:00:00Z",
          "completedAt": null,
          "completedBy": null,
          "statusHistories": [{
            "id": "history-1",
            "choreId": "chore-1",
            "status": 2,
            "updater": "user-2",
            "dateTime": "2026-10-10T10:00:00Z"
          }],
          "reviewRound": 1,
          "reviewVotes": [{
            "id": "vote-1",
            "choreId": "chore-1",
            "houseId": "house-1",
            "reviewRound": 1,
            "reviewerId": "user-1",
            "isApproved": true,
            "createdOn": "2026-10-10T10:30:00.456Z"
          }]
        }
        """.utf8
    )

    static let responseWithUnknownRawValues = Data(
        """
        {
          "id": "chore-unknown",
          "title": "Unknown raw values",
          "description": "Wire values stay intact",
          "houseId": "house-1",
          "houseOwnerId": "user-1",
          "assignedTo": "user-2",
          "dueDate": "2026-11-01T12:00:00Z",
          "isCompleted": false,
          "isRecurring": false,
          "level": 999,
          "recurringInterval": 0,
          "status": 99,
          "createdOn": "2026-10-10T09:00:00Z",
          "completedAt": null,
          "completedBy": null,
          "statusHistories": [],
          "reviewRound": 0,
          "reviewVotes": []
        }
        """.utf8
    )

    static let reviewResponse = Data(
        """
        {
          "id": "chore-1",
          "status": 3,
          "reviewRound": 2,
          "isCompleted": true,
          "reviewVotes": [{
            "id": "vote-2",
            "choreId": "chore-1",
            "houseId": "house-1",
            "reviewRound": 2,
            "reviewerId": "user-3",
            "isApproved": false,
            "createdOn": "2026-10-11T08:00:00Z"
          }]
        }
        """.utf8
    )

    static let malformedResponse = Data(
        """
        {
          "title": "Missing required fields",
          "houseId": "house-1"
        }
        """.utf8
    )
}
