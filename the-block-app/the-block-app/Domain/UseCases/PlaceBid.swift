@MainActor
struct PlaceBid {
    let repository: any BidRepository

    func callAsFunction(_ input: String, for vehicle: Vehicle) throws -> BidState {
        // The repository validates against its latest state within the serialized mutation.
        try repository.submit(BidPolicy().parse(input), for: vehicle)
    }
}
