import Foundation
import Combine
import FausCrewCore

@MainActor
final class DashboardStore: ObservableObject {
    @Published private(set) var members: [User] = []
    @Published private(set) var chores: [Chore] = []

    func setMembers(_ members: [User]) {
        guard self.members != members else { return }
        self.members = members
    }

    func setChores(_ chores: [Chore]) {
        guard self.chores != chores else { return }
        self.chores = chores
    }

    func rebuild(
        details: HouseDetailsResponse?,
        fallbackChores: [Chore],
        fallbackUnassignedName: String,
        currentUserId: String?,
        currentUserProfile: IsAuthUserData?
    ) {
        guard let details else {
            setMembers([])
            setChores(fallbackChores)
            return
        }

        let mappedMembers = details.members.map { member in
            user(from: member, currentUserId: currentUserId, currentUserProfile: currentUserProfile)
        }

        setMembers(mappedMembers)
        setChores(details.chores.map { chore(from: $0, unassignedName: fallbackUnassignedName) })
    }

    /// Maps a house chore with the store's current members, so `members` must be set first. The
    /// archive reuses it for chores that are not in `chores`.
    func chore(from dto: HouseChoreDTO, unassignedName: String) -> Chore {
        let assignedUser = members.first { $0.apiId == dto.assignedTo } ?? User(
            id: dto.assignedTo,
            name: dto.assignedTo.isEmpty ? unassignedName : dto.assignedTo
        )
        return Chore(
            choreApiId: dto.id,
            houseId: dto.houseId,
            assignedToId: dto.assignedTo,
            title: dto.title,
            description: dto.description,
            assignedTo: assignedUser,
            dueLabel: dto.dueLabelString,
            dueDate: dto.dueDate,
            isDone: dto.isCompleted,
            status: dto.status,
            level: dto.level,
            reviewRound: dto.reviewRound,
            reviewVotes: dto.reviewVotes,
            reviewPhotoRounds: dto.reviewPhotoRounds,
            failureReason: dto.failureReason,
            category: dto.category,
            completedAt: dto.completedAt,
            completedBy: dto.completedBy
        )
    }

    private func user(from member: HouseMemberDTO, currentUserId: String?, currentUserProfile: IsAuthUserData?) -> User {
        if member.id == currentUserId, let profile = currentUserProfile {
            return User(
                firstName: profile.firstName,
                lastName: profile.lastName,
                apiId: member.id,
                points: 0,
                imageUrl: profile.imageUrl.isEmpty ? nil : profile.imageUrl
            )
        }
        return User(
            firstName: member.firstName,
            lastName: member.lastName,
            apiId: member.id,
            points: 0,
            imageUrl: member.imageUrl.isEmpty ? nil : member.imageUrl
        )
    }
}
