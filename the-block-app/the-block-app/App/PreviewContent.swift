import SwiftUI

#Preview("Inventory") {
    InventoryView(viewModel: AppDependencies(bidSource: FileBidDataSource(
        url: URL.temporaryDirectory.appending(path: UUID().uuidString + "/preview-bids.json")
    )).makeInventoryViewModel())
    .environment(\.remoteVehicleImagesEnabled, false)
}

#Preview("Title status variants") {
    VStack(alignment: .leading, spacing: 16) {
        TitleStatusBadge(status: "clean")
        TitleStatusBadge(status: "rebuilt")
        TitleStatusBadge(status: "salvage")
    }
    .padding()
    .dynamicTypeSize(.accessibility5)
}

#Preview("Photo fallback") {
    VehiclePhotoGallery(images: ["unavailable", "unavailable"])
        .environment(\.remoteVehicleImagesEnabled, false)
        .padding()
}
