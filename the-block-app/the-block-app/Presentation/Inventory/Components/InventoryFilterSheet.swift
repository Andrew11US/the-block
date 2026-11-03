import SwiftUI

struct InventoryFilterSheet: View {
    let vehicles: [Vehicle]
    let apply: (VehicleFilters) -> Void
    @State private var draft: VehicleFilters
    @Environment(\.dismiss) private var dismiss

    init(vehicles: [Vehicle], filters: VehicleFilters, apply: @escaping (VehicleFilters) -> Void) {
        self.vehicles = vehicles
        self.apply = apply
        _draft = State(initialValue: filters)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") {
                    optionPicker("Make", selection: $draft.make, keyPath: \.make)
                        .accessibilityIdentifier("filterMake")
                    optionPicker("Body style", selection: $draft.bodyStyle, keyPath: \.bodyStyle)
                    optionPicker("Fuel type", selection: $draft.fuelType, keyPath: \.fuelType)
                    Picker("Year from", selection: $draft.minimumYear) {
                        Text("Any year").tag(Int?.none)
                        ForEach(Array(Set(vehicles.map(\.year))).sorted(by: >), id: \.self) { year in
                            Text(verbatim: String(year)).tag(Optional(year))
                        }
                    }
                    Picker("Maximum mileage", selection: $draft.maximumOdometerKm) {
                        Text("Any mileage").tag(Int?.none)
                        ForEach([25_000, 50_000, 100_000, 150_000, 200_000], id: \.self) { km in
                            Text("\(km.formatted()) km").tag(Optional(km))
                        }
                    }
                }
                Section("Condition and location") {
                    optionPicker("Title status", selection: $draft.titleStatus, keyPath: \.titleStatus)
                    optionPicker("Province", selection: $draft.province, keyPath: \.province)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        apply(VehicleFilters())
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(InventoryPalette.lotNavy)
                    .accessibilityLabel("Reset filters")
                    .accessibilityIdentifier("resetFilters")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    apply(draft)
                    dismiss()
                } label: {
                    Text("Apply")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(InventoryPalette.lotNavy)
                .accessibilityIdentifier("applyFilters")
                .padding(.horizontal)
                .padding(.bottom, 0)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func optionPicker(_ title: LocalizedStringKey, selection: Binding<String?>,
                              keyPath: KeyPath<Vehicle, String>) -> some View {
        Picker(title, selection: selection) {
            Text("Any").tag(String?.none)
            ForEach(Array(Set(vehicles.map { $0[keyPath: keyPath] })).sorted(), id: \.self) { option in
                Text(verbatim: option == option.lowercased() ? option.capitalized : option)
                    .tag(Optional(option))
            }
        }
    }
}
