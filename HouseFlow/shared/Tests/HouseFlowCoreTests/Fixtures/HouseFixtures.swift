import Foundation

enum HouseFixtures {
    static let responseWithStringDates = Data(
        """
        {
          "id": "house-1",
          "name": "String Date House",
          "inviteCode": "AB12CD34",
          "maxMemberCount": 4,
          "memberIds": ["user-1"],
          "ownerId": "user-1",
          "profileImage": "house.png",
          "type": 1,
          "createdOn": "2026-09-01T08:00:00Z",
          "updatedOn": "2026-09-02T08:00:00Z"
        }
        """.utf8
    )

    static let responseWithObjectDatesAndNullInvite = Data(
        """
        {
          "id": "house-2",
          "name": "Object Date House",
          "inviteCode": null,
          "maxMemberCount": 8,
          "memberIds": [],
          "ownerId": "user-2",
          "profileImage": "",
          "type": 2,
          "createdOn": { "time.Time": "2026-10-01T08:00:00Z" },
          "updatedOn": { "time.Time": "2026-10-02T08:00:00Z" }
        }
        """.utf8
    )

    static let detailsWithStringDates = Data(
        """
        {
          "id": "house-1",
          "name": "String Date House",
          "maxMemberCount": 4,
          "ownerId": "user-1",
          "profileImage": "",
          "type": 1,
          "createdOn": "2026-09-01T08:00:00Z",
          "updatedOn": "2026-09-02T08:00:00Z",
          "members": [{
            "id": "user-1",
            "firstName": "Ada",
            "lastName": "Lovelace",
            "email": "ada@example.com",
            "imageUrl": "",
            "isActive": true,
            "isVerifyEmail": true,
            "isVerifyPhone": false,
            "language": "en",
            "phoneNumber": "",
            "birthDay": "1990-01-01T00:00:00Z",
            "houseIds": ["house-1"],
            "createdOn": "2026-09-01T08:00:00Z",
            "updatedOn": "2026-09-02T08:00:00Z",
            "lastLogin": "2026-09-03T08:00:00Z"
          }],
          "chores": [],
          "activeAnnouncements": [{
            "announcementId": "announcement-1",
            "title": "Welcome",
            "body": "Welcome home",
            "createdAt": "2026-09-01T10:00:00Z",
            "updatedAt": null,
            "createdByUser": {
              "userId": "user-1",
              "firstName": "Ada",
              "lastName": "Lovelace"
            }
          }]
        }
        """.utf8
    )

    static let detailsWithObjectDatesAndNullOptionals = Data(
        """
        {
          "id": "house-2",
          "name": "Object Date House",
          "maxMemberCount": 8,
          "ownerId": "user-2",
          "profileImage": "",
          "type": 2,
          "createdOn": { "time.Time": "2026-10-01T08:00:00Z" },
          "updatedOn": { "time.Time": "2026-10-02T08:00:00Z" },
          "members": [{
            "id": "user-2",
            "firstName": "Grace",
            "lastName": "Hopper",
            "email": "grace@example.com",
            "imageUrl": "",
            "isActive": true,
            "isVerifyEmail": true,
            "isVerifyPhone": false,
            "language": null,
            "phoneNumber": "",
            "birthDay": null,
            "houseIds": ["house-2"],
            "createdOn": { "time.Time": "2026-10-01T08:00:00Z" },
            "updatedOn": { "time.Time": "2026-10-02T08:00:00Z" },
            "lastLogin": { "time.Time": "2026-10-03T08:00:00Z" }
          }],
          "chores": [{
            "id": "chore-1",
            "title": "Wash dishes",
            "description": "Kitchen",
            "houseId": "house-2",
            "houseOwnerId": "user-2",
            "assignedTo": "user-2",
            "dueDate": { "time.Time": "2026-10-04T18:00:00Z" },
            "isCompleted": false,
            "isRecurring": false,
            "level": 10,
            "recurringInterval": 0,
            "status": 0,
            "createdOn": { "time.Time": "2026-10-01T09:00:00Z" },
            "completedAt": null,
            "completedBy": null,
            "statusHistories": [{
              "id": "history-1",
              "choreId": "chore-1",
              "status": 0,
              "updater": "user-2",
              "dateTime": { "time.Time": "2026-10-01T09:00:00Z" }
            }],
            "reviewRound": 1,
            "reviewVotes": [{
              "id": "vote-1",
              "choreId": "chore-1",
              "houseId": "house-2",
              "reviewRound": 1,
              "reviewerId": "user-2",
              "isApproved": true,
              "createdOn": { "time.Time": "2026-10-01T10:00:00Z" }
            }]
          }],
          "announcements": [{
            "id": "announcement-2",
            "houseId": "house-2",
            "title": "Notice",
            "description": "Object dates work",
            "createdOn": { "time.Time": "2026-10-01T11:00:00Z" },
            "updatedOn": null,
            "announcedBy": "user-2"
          }]
        }
        """.utf8
    )

    static let houseInfo = Data(
        """
        {
          "houseMemberCount": 2,
          "houseMemberCountLimit": 8,
          "houseMembers": [
            { "isOwner": true, "name": "Ada", "profileImage": "", "userId": "user-1" },
            { "isOwner": false, "name": "Grace", "profileImage": "grace.png", "userId": "user-2" }
          ],
          "houseName": "Analytical House",
          "houseProfileImage": "house.png",
          "houseType": 1
        }
        """.utf8
    )

    static let malformedResponse = Data(
        """
        {
          "id": "house-1",
          "name": "Missing Owner",
          "maxMemberCount": 4,
          "memberIds": [],
          "profileImage": "",
          "type": 1,
          "createdOn": "2026-09-01T08:00:00Z",
          "updatedOn": "2026-09-02T08:00:00Z"
        }
        """.utf8
    )
}
