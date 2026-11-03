import SwiftUI

struct TitleStatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: presentation.icon)
            Text(presentation.text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(presentation.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(presentation.fill, in: RoundedRectangle(cornerRadius: 6))
    }

    private var presentation: (text: String, icon: String, ink: Color, fill: Color) {
        switch status {
        case "clean": (String(localized: "Clean title"), "checkmark.shield", InventoryPalette.cleanTitle, InventoryPalette.mist)
        case "rebuilt": (String(localized: "Rebuilt title"), "wrench.and.screwdriver", InventoryPalette.rebuiltTitle, InventoryPalette.rebuiltBackground)
        case "salvage": (String(localized: "Salvage title"), "exclamationmark.triangle", InventoryPalette.salvageTitle, InventoryPalette.salvageBackground)
        default: ("Title: \(status)", "doc.text", InventoryPalette.otherTitle, InventoryPalette.otherTitleBackground)
        }
    }
}
