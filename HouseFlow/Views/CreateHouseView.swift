import SwiftUI

struct CreateHouseView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var houseName = ""
    @State private var selectedHouseType: HouseType = .studentHouse
    @State private var memberCount = 3
    @State private var showSummaryPopup = false
    @State private var showInviteCodePopup = false
    @State private var generatedInviteCode = ""
    
    enum HouseType: String, CaseIterable {
        case studentHouse = "Student House"
        case sharedHouse = "Shared House"
        case dormRoom = "Dorm Room"
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Header with back button
            VStack(spacing: 8) {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appViewModel.backToHouseSelection()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                Text("Create New House")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Start by entering your home details")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            ScrollView {
                VStack(spacing: 32) {
                    // House Name Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("House Name")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Enter House Name", text: $houseName)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(houseName.isEmpty ? Color.clear : Color.blue, lineWidth: 2)
                                )
                                .animation(.easeInOut(duration: 0.2), value: houseName.isEmpty)
                                .onChange(of: houseName) { _, newValue in
                                    if newValue.count > 30 {
                                        houseName = String(newValue.prefix(30))
                                    }
                                }
                            
                            if !houseName.isEmpty {
                                Text("\(houseName.count)/30 char")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // House Type Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("House Type")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            ForEach(HouseType.allCases, id: \.self) { type in
                                HouseTypeCard(
                                    type: type,
                                    isSelected: selectedHouseType == type
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedHouseType = type
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Member Count Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Person Count")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            // Custom Train Track Slider
                            GeometryReader { geometry in
                                let padding: CGFloat = 22 // Padding from screen edges for bubble clearance
                                let sliderWidth = geometry.size.width - (padding * 2)
                                let stepWidth = sliderWidth / 6 // 6 intervals for 7 stops (2-8)
                                
                                ZStack {
                                    // Background rail (centered)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemGray4))
                                        .frame(width: sliderWidth, height: 6)
                                    
                                    // Train stops (centered with rail)
                                    HStack(spacing: 0) {
                                        ForEach(Array(stride(from: 2, through: 8, by: 1)), id: \.self) { count in
                                            VStack(spacing: 0) {
                                                Rectangle()
                                                    .fill(Color(.systemGray3))
                                                    .frame(width: 3, height: 16)
                                                    .cornerRadius(1.5)
                                                
                                                Circle()
                                                    .fill(memberCount >= count ? Color.blue : Color(.systemGray4))
                                                    .frame(width: 10, height: 10)
                                                    .animation(.easeOut(duration: 0.2), value: memberCount)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .frame(width: sliderWidth)
                                    
                                    // Floating bubble with number (perfect alignment)
                                    // Each stop gets equal space in HStack: sliderWidth / 7 stops
                                    // Center of each stop: (stopIndex * stopWidth) + (stopWidth / 2)
                                    let totalStops: CGFloat = 7 // We have 7 stops (2,3,4,5,6,7,8)
                                    let stopWidth = sliderWidth / totalStops
                                    let stopIndex = CGFloat(memberCount - 2) // 0-based index (2->0, 3->1, etc)
                                    let stopCenterFromLeft = (stopIndex * stopWidth) + (stopWidth / 2)
                                    let bubbleX = (geometry.size.width - sliderWidth) / 2 + stopCenterFromLeft
                                    
                                    VStack(spacing: 0) {
                                        // Bubble
                                        Text("\(memberCount)")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                Circle()
                                                    .fill(Color.blue)
                                                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 4)
                                            )
                                        
                                        // Bubble tail (triangle pointing down)
                                        Triangle()
                                            .fill(Color.blue)
                                            .frame(width: 14, height: 10)
                                            .offset(y: -1)
                                    }
                                    .position(x: bubbleX, y: 15)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: bubbleX)
                                }
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let clampedX = max(padding, min(geometry.size.width - padding, value.location.x))
                                            let normalizedPosition = (clampedX - padding) / sliderWidth
                                            let step = round(normalizedPosition * 6)
                                            let newCount = Int(step) + 2
                                            let clampedCount = max(2, min(8, newCount))
                                            
                                            if clampedCount != memberCount {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    memberCount = clampedCount
                                                }
                                            }
                                        }
                                )
                                .onTapGesture { location in
                                    let clampedX = max(padding, min(geometry.size.width - padding, location.x))
                                    let normalizedPosition = (clampedX - padding) / sliderWidth
                                    let step = round(normalizedPosition * 6)
                                    let newCount = Int(step) + 2
                                    let clampedCount = max(2, min(8, newCount))
                                    
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        memberCount = clampedCount
                                    }
                                }
                            }
                            .frame(height: 70)
                            
                            // Labels
                            HStack {
                                Text("Min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Max")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.vertical, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            
            // Create Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSummaryPopup = true
                }
            }) {
                Text("Create Home")
                    .font(.headline)
                    .foregroundColor(isFormValid ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isFormValid ? Color.blue : Color.gray.opacity(0.3))
                    .cornerRadius(16)
                    .animation(.easeInOut(duration: 0.2), value: isFormValid)
            }
            .disabled(!isFormValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        .navigationBarHidden(true)
        .overlay(
            Group {
                if showSummaryPopup {
                    HouseSummaryPopup(
                        houseName: houseName,
                        houseType: selectedHouseType.rawValue,
                        memberCount: memberCount,
                        onConfirm: {
                            showSummaryPopup = false
                            generatedInviteCode = generateInviteCode()
                            showInviteCodePopup = true
                        },
                        onCancel: {
                            showSummaryPopup = false
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                if showInviteCodePopup {
                    InviteCodePopup(
                        inviteCode: generatedInviteCode,
                        houseName: houseName,
                        onContinue: {
                            showInviteCodePopup = false
                            appViewModel.createHouse(
                                name: houseName,
                                type: selectedHouseType.rawValue,
                                memberCount: memberCount
                            )
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSummaryPopup)
            .animation(.easeInOut(duration: 0.3), value: showInviteCodePopup)
        )
    }
    
    private func generateInviteCode() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyazABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!*"
        return String((0..<8).map { _ in characters.randomElement()! })
    }
    
    private var isFormValid: Bool {
        !houseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct HouseTypeCard: View {
    let type: CreateHouseView.HouseType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .white : .blue)
                
                // Label
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch type {
        case .studentHouse:
            return "graduationcap.fill"
        case .sharedHouse:
            return "house.fill"
        case .dormRoom:
            return "building.2.fill"
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        
        return path
    }
}

struct HouseSummaryPopup: View {
    let houseName: String
    let houseType: String
    let memberCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Popup content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "house.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Review the information for the home to be created")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Summary details
                VStack(spacing: 16) {
                    SummaryRow(title: "House Name", value: houseName)
                    SummaryRow(title: "House Type", value: houseType)
                    SummaryRow(title: "Person count", value: "\(memberCount) persons")
                }
                .padding(.vertical, 16)
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Create House")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button(action: onCancel) {
                        Text("Edit")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
    }
}

struct InviteCodePopup: View {
    let inviteCode: String
    let houseName: String
    let onContinue: () -> Void
    @State private var showingShareSheet = false
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Popup content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("House Created! 🎉")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(houseName) successfully created")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Invite code section
                VStack(spacing: 16) {
                    Text("Invite Code")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        // Code display
                        Text(inviteCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            // Copy button
                            Button(action: {
                                UIPasteboard.general.string = inviteCode
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14))
                                    Text("Copy")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Share button
                            Button(action: {
                                showingShareSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14))
                                    Text("Share")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    Text("You can invite your friends to your home by sharing this cod")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                // Continue button
                Button(action: onContinue) {
                    Text("Entire House")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(
                activityItems: [createShareMessage()],
                applicationActivities: nil
            )
        }
    }
    
    private func createShareMessage() -> String {
        return """
        🏠 \(houseName)'e katılmaya davetlisiniz!
        
        HouseFlow uygulamasını indirin ve aşağıdaki davet kodunu kullanın:
        
        🔑 Davet Kodu: \(inviteCode)
        
        Ev işlerini birlikte organize edelim! 🧹✨
        """
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    CreateHouseView()
        .environmentObject(AppViewModel())
}
