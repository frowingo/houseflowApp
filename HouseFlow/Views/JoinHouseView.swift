import SwiftUI

struct JoinHouseView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var inviteCode: String = ""
    @State private var showError: Bool = false
    @State private var isValidating: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Button(action: {
                            appViewModel.backToHouseSelection()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "house.and.flag")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Join a House")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Enter the invite code shared by your friend")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.bottom, 40)
                
                // Content
                VStack(spacing: 24) {
                    // Invite code input
                    VStack(spacing: 16) {
                        Text("Invite Code")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            TextField("Entire Invite Code", text: $inviteCode)
                                .textFieldStyle(CustomTextFieldStyle(isError: showError))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isTextFieldFocused)
                                .onChange(of: inviteCode) { _ in
                                    showError = false
                                }
                                .onSubmit {
                                    joinHouse()
                                }
                            
                            if showError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    
                                    Text("Invalid invite code. Please check and try again.")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    
                    // Info box
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            
                            Text("How to get Invite Code ?")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            InfoRow(number: "1", text: "Ask the home owner for the invite code")
                            InfoRow(number: "2", text: "Enter the 6–8 character code above")
                            InfoRow(number: "3", text: "Tap \"Join House\" button")
                        }
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                // Join button
                VStack(spacing: 16) {
                    Button(action: joinHouse) {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            
                            Text(isValidating ? "Checking..." : "Join House")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            inviteCode.isEmpty ? Color.gray.opacity(0.3) : Color.blue
                        )
                        .cornerRadius(16)
                        .animation(.easeInOut(duration: 0.2), value: inviteCode.isEmpty)
                    }
                    .disabled(inviteCode.isEmpty || isValidating)
                    
                    // Demo codes hint
                    VStack(spacing: 4) {
                        Text("Demo Codes:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("HOUSE123 • DEMO456 • TEST789")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                inviteCode = "HOUSE123"
                            }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func joinHouse() {
        guard !inviteCode.isEmpty else { return }
        
        isValidating = true
        isTextFieldFocused = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let success = appViewModel.joinHouse(with: inviteCode)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                if !success {
                    showError = true
                    isTextFieldFocused = true
                }
                isValidating = false
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    let isError: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 18, weight: .medium, design: .monospaced))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isError ? Color.red : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isError)
    }
}

struct InfoRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    JoinHouseView()
        .environmentObject(AppViewModel())
}
