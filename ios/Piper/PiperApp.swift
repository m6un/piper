// PiperApp.swift — App entry point
import SwiftUI

@main
struct PiperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                cookieManager: CookieManager(),
                pipeline: PipelineController()
            )
        }
    }
}
