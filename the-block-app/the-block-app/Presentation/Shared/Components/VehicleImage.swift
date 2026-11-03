import SwiftUI

struct VehicleImage: View {
    let url: String?
    var priority: VehicleImageLoader.Priority = .inventory
    var requiresScrollVisibility = false
    @Environment(\.remoteVehicleImagesEnabled) private var remoteImagesEnabled
    @State private var isScrollVisible = false
    @State private var image: UIImage?
    @State private var loadedURL: URL?
    @State private var isLoading = false

    private struct LoadID: Equatable {
        let url: URL?
        let priority: VehicleImageLoader.Priority
    }

    private var loadID: LoadID {
        LoadID(url: remoteImagesEnabled && (!requiresScrollVisibility || isScrollVisible)
               ? remoteURL : nil, priority: priority)
    }

    private var displayedImage: UIImage? {
        guard let url = loadID.url else { return nil }
        if loadedURL == url, let image { return image }
        // TabView can create pages lazily: show a prefetched image on the first frame.
        return VehicleImageLoader.shared.cachedImage(for: url)
    }

    var body: some View {
        Group {
            if let image = displayedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                fallback
                    .overlay { if isLoading { ProgressView() } }
            }
        }
        .accessibilityHidden(true)
        .onScrollVisibilityChange(threshold: 0.01) { isScrollVisible = $0 }
        .task(id: loadID) {
            if loadedURL != loadID.url {
                image = nil
                loadedURL = nil
            }
            isLoading = false
            guard let url = loadID.url else { return }
            isLoading = true
            do {
                let loaded = try await VehicleImageLoader.shared.image(for: url, priority: priority)
                try Task.checkCancellation()
                loadedURL = url
                image = loaded
                isLoading = false
            } catch {
                // A replaced task owns the new state after cancellation.
                if !Task.isCancelled { isLoading = false }
            }
        }
    }

    private var remoteURL: URL? {
        url.flatMap(VehicleImageLoader.remoteURL)
    }

    private var fallback: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "car.side")
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .foregroundStyle(.secondary)
            }
    }
}

private struct RemoteVehicleImagesEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var remoteVehicleImagesEnabled: Bool {
        get { self[RemoteVehicleImagesEnabledKey.self] }
        set { self[RemoteVehicleImagesEnabledKey.self] = newValue }
    }
}
