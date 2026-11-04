import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var coordinator: AppCoordinator?
    private var environment: AppEnvironment?
    private var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let container = makeModelContainer()
        modelContainer = container
        let environment = AppEnvironment(modelContainer: container)
        let coordinator = AppCoordinator(environment: environment)
        self.environment = environment
        self.coordinator = coordinator
        coordinator.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Opens the on-disk store; if that fails (corrupt store, failed migration) falls back to a
    /// temporary in-memory store and tells the user, instead of crashing a menu-bar app silently.
    private func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: PicoSchemaV1.self),
                migrationPlan: PicoMigrationPlan.self,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: false)]
            )
        } catch {
            do {
                let fallback = try ModelContainer(
                    for: Schema(versionedSchema: PicoSchemaV1.self),
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
                presentStoreFailure(error)
                return fallback
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    private func presentStoreFailure(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Pico couldn’t open your saved history"
        alert.informativeText = "Pico will run without saved history this time. Your existing data was not deleted.\n\n\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
