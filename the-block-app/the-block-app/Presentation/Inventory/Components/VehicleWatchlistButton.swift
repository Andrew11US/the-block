import SwiftUI

struct VehicleWatchlistButton: View {
    let vehicle: Vehicle
    let isSaved: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Image(systemName: isSaved ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(isSaved ? Color.red : Color.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(isSaved ? "Remove from watchlist" : "Add to watchlist"): \(VehicleDisplayFormatter.identity(vehicle)), lot \(vehicle.lot)")
        .accessibilityValue(isSaved ? "Saved" : "Not saved")
        .accessibilityIdentifier("watchlist-\(vehicle.lot)")
    }
}
