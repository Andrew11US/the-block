import SwiftUI

struct VehicleConditionSection: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VehicleDetailCardHeading(title: "Condition", icon: "checklist")
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(vehicle.conditionGrade.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 30, weight: .semibold))
                        .tracking(-1)
                    Text("/ 5")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            Text(verbatim: vehicle.conditionReport)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .accessibilityIdentifier("conditionReport")
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Label(vehicle.damageNotes.isEmpty ? "No damage notes provided" : "Damage notes", systemImage: "list.clipboard")
                    .font(.system(size: 11, weight: vehicle.damageNotes.isEmpty ? .regular : .semibold))
                ForEach(vehicle.damageNotes.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(InventoryPalette.rebuiltTitle)
                        Text(verbatim: vehicle.damageNotes[index])
                    }
                    .font(.system(size: 12))
                }
            }
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(InventoryPalette.navy)
        .padding(16)
        .vehicleDetailSurface()
    }
}
