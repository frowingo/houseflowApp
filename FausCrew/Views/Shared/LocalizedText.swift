import SwiftUI

struct LocalizedText: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let key: String
    let replacements: [String: String]

    init(_ key: String, replacements: [String: String] = [:]) {
        self.key = key
        self.replacements = replacements
    }

    var body: some View {
        Text(appViewModel.localized(key, replacements: replacements))
    }
}
