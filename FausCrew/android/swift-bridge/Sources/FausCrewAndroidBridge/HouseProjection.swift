import Foundation
import FausCrewCore

// What Android reads from a house or dashboard response: Core's decoded DTOs, so the wire's key
// aliases, time shapes and derived values are resolved once, under one flat key per field.

func houseDetailsObject(_ house: HouseDetailsResponse) -> [String: Any] {
    [
        "id": house.id,
        "name": house.name,
        "ownerId": house.ownerId,
        "isChoreReviewPhotoRequired": house.isChoreReviewPhotoRequired,
        "members": house.members.map(memberObject),
        "chores": house.chores.map(choreObject),
        "announcements": house.announcements.map(announcementObject),
    ]
}

func choreObject(_ chore: HouseChoreDTO) -> [String: Any] {
    var object: [String: Any] = [
        "id": chore.id,
        "houseId": chore.houseId,
        "title": chore.title,
        "description": chore.description,
        "assignedTo": chore.assignedTo,
        "dueDate": chore.dueDate,
        "status": chore.status,
        "isCompleted": chore.isCompleted,
        "isRecurring": chore.isRecurring,
        "level": chore.level,
        "recurringInterval": chore.recurringInterval,
        "reviewRound": chore.reviewRound,
        "reviewVotes": chore.reviewVotes.map(voteObject),
        "reviewPhotoRounds": chore.reviewPhotoRounds,
        "category": chore.categoryKind.rawValue,
    ]
    if let reason = chore.failureReason { object["failureReason"] = reason.rawValue }
    if let completedAt = chore.completedAt { object["completedAt"] = completedAt }
    if let completedBy = chore.completedBy { object["completedBy"] = completedBy }
    return object
}

func voteObject(_ vote: ChoreReviewVote) -> [String: Any] {
    ["reviewRound": vote.reviewRound, "reviewerId": vote.reviewerId, "isApproved": vote.isApproved]
}

func announcementObject(_ announcement: HouseAnnouncementDTO) -> [String: Any] {
    var object: [String: Any] = [
        "id": announcement.id,
        "title": announcement.title,
        "message": announcement.message,
        "createdOn": announcement.createdOn,
        "isActive": announcement.isActive,
    ]
    if let houseId = announcement.houseId { object["houseId"] = houseId }
    if let publisherId = announcement.publisherId { object["publisherId"] = publisherId }
    if let publisherName = announcement.publisherName { object["publisherName"] = publisherName }
    return object
}

private func memberObject(_ member: HouseMemberDTO) -> [String: Any] {
    [
        "id": member.id,
        "firstName": member.firstName,
        "lastName": member.lastName,
        "imageUrl": member.imageUrl,
    ]
}
