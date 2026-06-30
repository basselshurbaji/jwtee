import SwiftUI

@main
struct JWTeeApp: App {
    var body: some Scene {
        WindowGroup("JWTee") {
            ContentView()
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
    }
}
