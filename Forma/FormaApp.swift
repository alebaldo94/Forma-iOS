import SwiftUI

@main
struct FormaApp: App {
    @StateObject private var session = Session()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.loggato { WorkoutListView() } else { LoginView() }
            }
            .environmentObject(session)
        }
    }
}
