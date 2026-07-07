import Foundation
import Combine

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
        fallbackMembers: [User],
        fallbackChores: [Chore],
        fallbackUnassignedName: String,
        currentUserId: String?,
        currentUserProfile: IsAuthUserData?
    ) {
        guard let details else {
            setMembers(fallbackMembers)
            setChores(fallbackChores)
            return
        }

        let mappedMembers = details.members.map { member in
            user(from: member, currentUserId: currentUserId, currentUserProfile: currentUserProfile)
        }
        let membersById = Dictionary(uniqueKeysWithValues: mappedMembers.compactMap { user -> (String, User)? in
            guard let apiId = user.apiId else { return nil }
            return (apiId, user)
        })

        setMembers(mappedMembers)
        setChores(details.chores.map { dto in
            let assignedUser = membersById[dto.assignedTo] ?? User(
                id: dto.assignedTo,
                name: dto.assignedTo.isEmpty ? fallbackUnassignedName : dto.assignedTo
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
                reviewVotes: dto.reviewVotes
            )
        })
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
