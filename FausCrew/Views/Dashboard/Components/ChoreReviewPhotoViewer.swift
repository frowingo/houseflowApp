import SwiftUI
import UIKit

private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

/// Full-screen review photo, the only place a review photo is shown. The photo and
/// its controls live inside a secure canvas that screenshots and recordings leave
/// out, so captures show the "capture blocked" screen underneath instead. Any
/// capture attempt also reports `onCaptureAttempt` so the caller can close the viewer.
struct ChoreReviewPhotoViewer: View {
    let image: UIImage
    let closeLabel: String
    let blockedTitle: String
    let blockedMessage: String
    let onClose: () -> Void
    let onCaptureAttempt: () -> Void

    var body: some View {
        ZStack {
            ChoreReviewPhotoCaptureBlockedView(title: blockedTitle, message: blockedMessage)

            ScreenshotProtected(content: photoContent, onCaptureAttempt: onCaptureAttempt)
                .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            onCaptureAttempt()
        }
    }

    private var photoContent: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .accessibilityLabel(closeLabel)
            .padding(AppDesign.Spacing.lg)
        }
    }
}

/// What screenshots and recordings of the review photo viewer contain.
struct ChoreReviewPhotoCaptureBlockedView: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            MainScreenBackground()
                .ignoresSafeArea()

            VStack(spacing: AppDesign.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(accentOrange.opacity(0.12))
                        .frame(width: 112, height: 112)
                    Circle()
                        .fill(LinearGradient(
                            colors: [accentOrange, accentOrange.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(AppDesign.Typography.title3)
                    .foregroundColor(AppDesign.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
    }
}

private struct ScreenshotProtected<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let onCaptureAttempt: () -> Void

    func makeUIViewController(context: Context) -> ScreenshotProtectedController<Content> {
        ScreenshotProtectedController(content: content, onCaptureAttempt: onCaptureAttempt)
    }

    func updateUIViewController(_ uiViewController: ScreenshotProtectedController<Content>, context: Context) {
        uiViewController.update(content: content, onCaptureAttempt: onCaptureAttempt)
    }
}

/// Hosts SwiftUI content in a secure text field's canvas, which the system leaves out
/// of screenshots, recordings and mirroring. If that canvas is unavailable the content
/// is shown normally and the capture callbacks still close the viewer.
final class ScreenshotProtectedController<Content: View>: UIViewController {
    private let hosting: UIHostingController<Content>
    private let secureField = UITextField()
    private var onCaptureAttempt: () -> Void

    init(content: Content, onCaptureAttempt: @escaping () -> Void) {
        hosting = UIHostingController(rootView: content)
        self.onCaptureAttempt = onCaptureAttempt
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        secureField.isSecureTextEntry = true
        let container = secureField.subviews.first ?? UIView()
        container.subviews.forEach { $0.removeFromSuperview() }
        container.isUserInteractionEnabled = true
        pin(container, in: view)

        addChild(hosting)
        hosting.view.backgroundColor = .clear
        pin(hosting.view, in: container)
        hosting.didMove(toParent: self)

        registerForTraitChanges([UITraitSceneCaptureState.self]) { (controller: Self, _: UITraitCollection) in
            controller.reportActiveCapture()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reportActiveCapture()
    }

    func update(content: Content, onCaptureAttempt: @escaping () -> Void) {
        hosting.rootView = content
        self.onCaptureAttempt = onCaptureAttempt
    }

    /// Screen recording or mirroring that is already running counts as a capture attempt.
    private func reportActiveCapture() {
        guard view.window != nil, traitCollection.sceneCaptureState == .active else { return }
        onCaptureAttempt()
    }

    private func pin(_ child: UIView, in parent: UIView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])
    }
}
