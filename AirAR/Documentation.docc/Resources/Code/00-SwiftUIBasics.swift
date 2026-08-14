import SwiftUI

@main
struct AirARApp: App {
    var body: some Scene {
        WindowGroup {
            CounterView()
        }
    }
}

struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("버튼을 누른 횟수: " + String(count))
            Button("한 번 더") {
                count += 1
            }
        }
    }
}
