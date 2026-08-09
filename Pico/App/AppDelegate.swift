import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var coordinator: AppCoordinator?
    private var environment: AppEnvironment?
    private var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let schema = Schema([Conversation.self, Message.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            modelContainer = container
            let environment = AppEnvironment(modelContainer: container)
            let coordinator = AppCoordinator(environment: environment)
            self.environment = environment
            self.coordinator = coordinator
            coordinator.start()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
