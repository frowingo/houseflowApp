
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            LocalizedText("app_name")
                .padding()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
