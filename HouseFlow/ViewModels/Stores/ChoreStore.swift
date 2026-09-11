import Foundation
import Combine

@MainActor
final class ChoreStore: ObservableObject {
    @Published private(set) var chores: [Chore] = []

    private let choreService: any ChoreServicing

    init(choreService: any ChoreServicing) {
        self.choreService = choreService
    }

    func setChores(_ chores: [Chore]) {
        guard self.chores != chores else { return }
        self.chores = chores
    }

    func clear() {
        setChores([])
    }

    func toggleCompletion(_ choreId: String) {
        guard let index = chores.firstIndex(where: { $0.id == choreId }) else { return }
        let c = chores[index]
        var updatedChores = chores
        updatedChores[index] = Chore(
            id: c.id,
            choreApiId: c.choreApiId,
            houseId: c.houseId,
            assignedToId: c.assignedToId,
            title: c.title,
            description: c.description,
            assignedTo: c.assignedTo,
            dueLabel: c.dueLabel,
            dueDate: c.dueDate,
            isDone: !c.isDone,
            status: c.isDone ? 0 : 3,
            level: c.level,
            reviewRound: c.reviewRound,
            reviewVotes: c.reviewVotes
        )
        setChores(updatedChores)
    }

    func apply(response: ChoreResponse, currentHouseDetails: HouseDetailsResponse?, dashboardMembers: [User]) -> HouseDetailsResponse? {
        let mergedChore = chore(from: response, dashboardMembers: dashboardMembers)
        if let index = chores.firstIndex(where: { $0.choreApiId == response.id }) {
            var updatedChores = chores
            updatedChores[index] = mergedChore
            setChores(updatedChores)
        } else if currentHouseDetails == nil {
            setChores(chores + [mergedChore])
        }

        guard let details = currentHouseDetails else { return nil }
        let responseDTO = response.houseChoreDTO
        let hasExistingChore = details.chores.contains { $0.id == response.id }
        let mergedChores = hasExistingChore
            ? details.chores.map { $0.id == response.id ? responseDTO : $0 }
            : details.chores + [responseDTO]

        return HouseDetailsResponse(
            id: details.id,
            name: details.name,
            inviteCode: details.inviteCode,
            maxMemberCount: details.maxMemberCount,
            ownerId: details.ownerId,
            profileImage: details.profileImage,
            type: details.type,
            createdOn: details.createdOn,
            updatedOn: details.updatedOn,
            members: details.members,
            chores: mergedChores,
            announcements: details.announcements
        )
    }

    func createChore(
        assignedToId: String,
        description: String,
        dueDate: Date,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String,
        currentHouseDetails: HouseDetailsResponse?,
        dashboardMembers: [User]
    ) async throws -> HouseDetailsResponse? {
        let createdChore = try await choreService.createChore(
            assignedTo: assignedToId,
            description: description,
            dueDate: HouseFlowDateFormatter.apiString(from: dueDate),
            houseId: houseId,
            isRecurring: isRecurring,
            level: level,
            recurringInterval: recurringInterval,
            title: title
        )
        return apply(response: createdChore, currentHouseDetails: currentHouseDetails, dashboardMembers: dashboardMembers)
    }

    func updateStatus(
        choreApiId: String,
        houseId: String,
        status: ChoreStatus,
        currentHouseDetails: HouseDetailsResponse?,
        dashboardMembers: [User]
    ) async throws -> (didUpdate: Bool, updatedDetails: HouseDetailsResponse?) {
        let updatedChores = try await choreService.updateChoreStatus(
            houseId: houseId,
            chores: [ChoreStatusUpdateItem(choreId: choreApiId, status: status.rawValue)]
        )
        guard !updatedChores.isEmpty else {
            return (false, nil)
        }

        var latestDetails = currentHouseDetails
        for updatedChore in updatedChores {
            latestDetails = apply(
                response: updatedChore,
                currentHouseDetails: latestDetails,
                dashboardMembers: dashboardMembers
            ) ?? latestDetails
        }
        return (true, latestDetails)
    }

    func review(
        choreApiId: String,
        isApproved: Bool,
        currentHouseDetails: HouseDetailsResponse?,
        dashboardMembers: [User]
    ) async throws -> HouseDetailsResponse? {
        let updatedChore = try await choreService.reviewChore(
            choreId: choreApiId,
            isApproved: isApproved
        )
        return apply(response: updatedChore, currentHouseDetails: currentHouseDetails, dashboardMembers: dashboardMembers)
    }

    private func chore(from response: ChoreResponse, dashboardMembers: [User]) -> Chore {
        let assignedUser = dashboardMembers.first(where: { $0.apiId == response.assignedTo })
            ?? User(id: response.assignedTo, name: response.assignedTo.isEmpty ? "Unassigned" : response.assignedTo)
        return Chore(
            choreApiId: response.id,
            houseId: response.houseId,
            assignedToId: response.assignedTo,
            title: response.title,
            description: response.description,
            assignedTo: assignedUser,
            dueLabel: HouseFlowDateFormatter.dueLabel(from: response.dueDate),
            dueDate: response.dueDate,
            isDone: response.isCompleted,
            status: response.status,
            level: response.level,
            reviewRound: response.reviewRound,
            reviewVotes: response.reviewVotes
        )
    }
}
