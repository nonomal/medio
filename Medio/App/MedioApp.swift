import SwiftUI
import AppKit

@main
struct MedioApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .background(WindowAccessor())
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
