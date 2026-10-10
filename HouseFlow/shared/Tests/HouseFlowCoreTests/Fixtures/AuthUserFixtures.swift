import Foundation

enum AuthUserFixtures {
    static let authenticatedUser = Data(
        """
        {
          "success": true,
          "data": {
            "birthDay": "1990-01-01T00:00:00Z",
            "createdOn": "2026-01-01T00:00:00Z",
            "email": "ada@example.com",
            "firstName": "Ada",
            "houseList": [
              {
                "houseId": "house-1",
                "houseName": "Analytical House",
                "houseProfile": "house.png"
              }
            ],
            "id": "user-1",
            "imageUrl": "ada.png",
            "isActive": true,
            "isVerifyEmail": true,
            "isVerifyPhone": false,
            "language": "en",
            "lastLogin": "2026-01-02T00:00:00Z",
            "lastName": "Lovelace",
            "phoneNumber": "",
            "updatedOn": "2026-01-03T00:00:00Z"
          }
        }
        """.utf8
    )

    static let userProfileWithNullOptionals = Data(
        """
        {
          "id": "user-2",
          "firstName": "Grace",
          "lastName": "Hopper",
          "email": "grace@example.com",
          "imageUrl": "",
          "birthDay": null,
          "isActive": true,
          "isVerifyEmail": true,
          "isVerifyPhone": false,
          "language": null,
          "phoneNumber": "",
          "houseIds": [],
          "createdOn": "2026-02-01T00:00:00Z",
          "updatedOn": "2026-02-02T00:00:00Z",
          "lastLogin": "2026-02-03T00:00:00Z"
        }
        """.utf8
    )

    static let imagesResponse = Data(
        """
        {
          "success": true,
          "data": [
            {
              "createdOn": "2026-03-01T00:00:00Z",
              "fileName": "avatar.png",
              "fileURL": "https://example.com/avatar.png",
              "publicId": "avatar-1",
              "updatedOn": "2026-03-02T00:00:00Z"
            }
          ]
        }
        """.utf8
    )

    static let malformedAuthenticatedUser = Data(
        """
        {
          "success": true,
          "data": {
            "id": "user-1",
            "email": "ada@example.com"
          }
        }
        """.utf8
    )
}
