import Foundation

// MARK: - Authentication requests

public struct SignupRequest: Encodable, Sendable {
    public let email: String
    public let password: String
    public let firstName: String
    public let lastName: String

    public init(email: String, password: String, firstName: String, lastName: String) {
        self.email = email
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
    }
}

public struct LoginRequest: Encodable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct ForgotPasswordRequest: Encodable, Sendable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

public struct ResetPasswordRequest: Encodable, Sendable {
    public let email: String
    public let code: String
    public let newPassword: String

    public init(email: String, code: String, newPassword: String) {
        self.email = email
        self.code = code
        self.newPassword = newPassword
    }
}

public struct ValidateEmailRequest: Encodable, Sendable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

// MARK: - Authentication responses

public struct AuthTokenResponse: Decodable, Sendable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

public struct ForgotPasswordResponse: Decodable, Sendable {
    public let success: Bool

    public init(success: Bool) {
        self.success = success
    }
}

public struct ValidateEmailResponse: Decodable, Sendable {
    public let success: Bool

    public init(success: Bool) {
        self.success = success
    }
}

public struct MessageResponse: Decodable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public struct IsAuthResponse: Decodable, Sendable {
    public let data: IsAuthUserData?
    public let success: Bool

    public init(data: IsAuthUserData?, success: Bool) {
        self.data = data
        self.success = success
    }
}

public struct AuthHouseSummary: Decodable, Equatable, Identifiable, Sendable {
    public let houseId: String
    public let houseName: String
    public let houseProfile: String

    public var id: String { houseId }

    public init(houseId: String, houseName: String, houseProfile: String) {
        self.houseId = houseId
        self.houseName = houseName
        self.houseProfile = houseProfile
    }
}

public struct IsAuthUserData: Decodable, Sendable {
    public let birthDate: String?
    public let createdOn: String
    public let email: String
    public let firstName: String
    public var houseList: [AuthHouseSummary]
    public let id: String
    public let imageUrl: String
    public let isActive: Bool
    public let isVerifyEmail: Bool
    public let isVerifyPhone: Bool
    public let language: String?
    public let lastLogin: String
    public let lastName: String
    public let phoneNumber: String
    public let updatedOn: String

    public var fullName: String { "\(firstName) \(lastName)" }

    public init(
        birthDate: String?,
        createdOn: String,
        email: String,
        firstName: String,
        houseList: [AuthHouseSummary],
        id: String,
        imageUrl: String,
        isActive: Bool,
        isVerifyEmail: Bool,
        isVerifyPhone: Bool,
        language: String?,
        lastLogin: String,
        lastName: String,
        phoneNumber: String,
        updatedOn: String
    ) {
        self.birthDate = birthDate
        self.createdOn = createdOn
        self.email = email
        self.firstName = firstName
        self.houseList = houseList
        self.id = id
        self.imageUrl = imageUrl
        self.isActive = isActive
        self.isVerifyEmail = isVerifyEmail
        self.isVerifyPhone = isVerifyPhone
        self.language = language
        self.lastLogin = lastLogin
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.updatedOn = updatedOn
    }

    private enum CodingKeys: String, CodingKey {
        case birthDate = "birthDay"
        case createdOn, email, firstName, houseList, id, imageUrl
        case isActive, isVerifyEmail, isVerifyPhone, language, lastLogin, lastName
        case phoneNumber, updatedOn
    }
}

// MARK: - User profile

public struct UserResultModel: Decodable, Sendable {
    public let id: String
    public let firstName: String
    public let lastName: String
    public let email: String
    public let imageUrl: String
    public let birthDate: String?
    public let isActive: Bool
    public let isVerifyEmail: Bool
    public let isVerifyPhone: Bool
    public let language: String?
    public let phoneNumber: String
    public let houseIds: [String]
    public let createdOn: String
    public let updatedOn: String
    public let lastLogin: String

    public var fullName: String { "\(firstName) \(lastName)" }

    public init(
        id: String,
        firstName: String,
        lastName: String,
        email: String,
        imageUrl: String,
        birthDate: String?,
        isActive: Bool,
        isVerifyEmail: Bool,
        isVerifyPhone: Bool,
        language: String?,
        phoneNumber: String,
        houseIds: [String],
        createdOn: String,
        updatedOn: String,
        lastLogin: String
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.imageUrl = imageUrl
        self.birthDate = birthDate
        self.isActive = isActive
        self.isVerifyEmail = isVerifyEmail
        self.isVerifyPhone = isVerifyPhone
        self.language = language
        self.phoneNumber = phoneNumber
        self.houseIds = houseIds
        self.createdOn = createdOn
        self.updatedOn = updatedOn
        self.lastLogin = lastLogin
    }

    private enum CodingKeys: String, CodingKey {
        case birthDate = "birthDay"
        case createdOn, email, firstName, houseIds, id, imageUrl
        case isActive, isVerifyEmail, isVerifyPhone, language, lastLogin, lastName
        case phoneNumber, updatedOn
    }
}

public struct UpdateProfileRequest: Encodable, Sendable {
    public let imageUrl: String?
    public let birthDay: String?
    public let firstName: String?
    public let lastName: String?
    public let phoneNumber: String?
    public let language: String?

    public init(
        imageUrl: String?,
        birthDay: String?,
        firstName: String?,
        lastName: String?,
        phoneNumber: String?,
        language: String? = nil
    ) {
        self.imageUrl = imageUrl
        self.birthDay = birthDay
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.language = language
    }
}

public typealias UpdateProfileData = UserResultModel

public struct UpdateProfileResponse: Decodable, Sendable {
    public let data: UpdateProfileData?
    public let success: Bool
    public let error: String?

    public init(data: UpdateProfileData?, success: Bool, error: String?) {
        self.data = data
        self.success = success
        self.error = error
    }
}

// MARK: - User image

public struct UserImageData: Decodable, Sendable {
    public let createdOn: String
    public let fileName: String
    public let fileURL: String
    public let publicId: String
    public let updatedOn: String

    public init(
        createdOn: String,
        fileName: String,
        fileURL: String,
        publicId: String,
        updatedOn: String
    ) {
        self.createdOn = createdOn
        self.fileName = fileName
        self.fileURL = fileURL
        self.publicId = publicId
        self.updatedOn = updatedOn
    }
}

public struct GetImageResponse: Decodable, Sendable {
    public let data: [UserImageData]
    public let success: Bool

    public init(data: [UserImageData], success: Bool) {
        self.data = data
        self.success = success
    }
}

public struct GetImagesResponse: Decodable, Sendable {
    public let data: [UserImageData]
    public let success: Bool

    public init(data: [UserImageData], success: Bool) {
        self.data = data
        self.success = success
    }
}
