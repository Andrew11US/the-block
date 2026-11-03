@MainActor
struct ResetDemoBids {
    let repository: any BidRepository
    func callAsFunction() throws { try repository.reset() }
}
