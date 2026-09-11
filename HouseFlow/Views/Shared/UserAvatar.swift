import SwiftUI

/// Kullanıcı avatarı component'i - imageUrl varsa gösterir, yoksa initials fallback
struct UserAvatar: View {
    let user: User
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString = user.imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                CachedRemoteImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView
                } failure: {
                    initialsView
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Text(user.initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(AppDesign.Colors.primary)
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
