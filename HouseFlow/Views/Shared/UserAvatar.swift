import SwiftUI

/// Kullanıcı avatarı component'i - initials ile dairesel avatar gösterir
struct UserAvatar: View {
    let user: User
    let size: CGFloat
    
    var body: some View {
        Text(user.initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(AppDesign.Colors.primary)
            .clipShape(Circle())
    }
}

#Preview("Small Avatar") {
    UserAvatar(
        user: User(name: "John Doe", points: 10),
        size: AppDesign.Size.avatarSmall
    )
}

#Preview("Medium Avatar") {
    UserAvatar(
        user: User(name: "Jane Smith", points: 15),
        size: AppDesign.Size.avatarMedium
    )
}

#Preview("Large Avatar") {
    UserAvatar(
        user: User(name: "Bob Wilson", points: 20),
        size: AppDesign.Size.avatarLarge
    )
}
