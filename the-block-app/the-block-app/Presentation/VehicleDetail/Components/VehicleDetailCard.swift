import SwiftUI

struct VehicleDetailCardHeading: View {
    let title: LocalizedStringKey
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 30, height: 30)
                .background(InventoryPalette.mist, in: RoundedRectangle(cornerRadius: 9))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(InventoryPalette.navy)
    }
}

private struct VehicleDetailSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InventoryPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(InventoryPalette.navy.opacity(0.10), lineWidth: 1)
            }
    }
}

extension View {
    func vehicleDetailSurface() -> some View {
        modifier(VehicleDetailSurface())
    }
}
