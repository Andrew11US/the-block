import SwiftUI

@main
struct TheBlockApp: App {
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            InventoryView(viewModel: dependencies.makeInventoryViewModel())
                .environment(\.remoteVehicleImagesEnabled,
                             !ProcessInfo.processInfo.arguments.contains("--offline-images"))
        }
    }
}
