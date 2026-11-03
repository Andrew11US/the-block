@MainActor
protocol BidRepository: AnyObject {
    var states: [String: BidState] { get }
    var restorationFailed: Bool { get }
    func state(for vehicle: Vehicle) -> BidState
    func updates() -> AsyncStream<[String: BidState]>
    func submit(_ amount: Int, for vehicle: Vehicle) throws -> BidState
    func reset() throws
}
