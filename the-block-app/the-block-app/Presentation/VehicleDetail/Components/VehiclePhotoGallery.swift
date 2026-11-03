import SwiftUI

struct VehiclePhotoGallery: View {
    let images: [String]
    @State private var page = 0
    @Environment(\.remoteVehicleImagesEnabled) private var remoteImagesEnabled

    var body: some View {
        VStack(spacing: 0) {
            if images.isEmpty {
                VehicleImage(url: nil).frame(height: 220).clipped()
                Text("No images provided").font(.system(size: 12)).padding(12)
            } else {
                TabView(selection: $page) {
                    ForEach(images.indices, id: \.self) { index in
                        VehicleImage(url: images[index], priority: page == index ? .detail : .gallery)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .overlay(alignment: .bottomTrailing) {
                                Text("\(index + 1) / \(images.count)")
                                    .font(.system(size: 11, weight: .medium))
                                    .monospacedDigit()
                                    .padding(6)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                                    .padding(10)
                            }
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 190)
                HStack {
                    previous
                    Spacer(minLength: 8)
                    HStack(spacing: 2) {
                        ForEach(images.indices, id: \.self) { index in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { page = index }
                            } label: {
                                Capsule()
                                    .fill(InventoryPalette.navy.opacity(page == index ? 1 : 0.25))
                                    .frame(width: page == index ? 18 : 6, height: 6)
                                    .frame(width: 24, height: 28)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Photo \(index + 1) of \(images.count)")
                            .accessibilityAddTraits(page == index ? .isSelected : [])
                        }
                    }
                    Spacer(minLength: 8)
                    next
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .foregroundStyle(InventoryPalette.navy)
        .background(InventoryPalette.card)
        .task(id: remoteImagesEnabled ? images : []) {
            guard remoteImagesEnabled else { return }
            await VehicleImageLoader.shared.prefetchGallery(images)
        }
    }

    private var previous: some View {
        Button("Previous photo", systemImage: "chevron.left") {
            withAnimation(.easeInOut(duration: 0.2)) { page -= 1 }
        }
            .labelStyle(.iconOnly)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 30, height: 30)
            .background(InventoryPalette.mist, in: RoundedRectangle(cornerRadius: 8))
            .disabled(page == 0)
            .buttonStyle(.borderless)
    }

    private var next: some View {
        Button("Next photo", systemImage: "chevron.right") {
            withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
        }
            .labelStyle(.iconOnly)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 30, height: 30)
            .background(InventoryPalette.mist, in: RoundedRectangle(cornerRadius: 8))
            .disabled(page >= images.count - 1)
            .buttonStyle(.borderless)
    }
}
