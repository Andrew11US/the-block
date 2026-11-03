import SwiftUI

enum InventoryPalette {
    static let lotNavy = Color(red: 24 / 255, green: 46 / 255, blue: 73 / 255)
    static let navy = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.89, green: 0.93, blue: 0.97, alpha: 1)
            : UIColor(red: 24 / 255, green: 46 / 255, blue: 73 / 255, alpha: 1)
    })
    static let mist = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.22, blue: 0.29, alpha: 1)
            : UIColor(red: 233 / 255, green: 242 / 255, blue: 248 / 255, alpha: 1)
    })
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let cleanTitle = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.85, blue: 0.72, alpha: 1)
            : UIColor(red: 23 / 255, green: 99 / 255, blue: 79 / 255, alpha: 1)
    })
    static let rebuiltTitle = adaptive(light: 0x8A4B08, dark: 0xFFD18A)
    static let liveBackground = adaptive(light: 0xE2F3E9, dark: 0x18392D)
    static let rebuiltBackground = adaptive(light: 0xFFF0D6, dark: 0x44321C)
    static let salvageTitle = adaptive(light: 0xA32635, dark: 0xFFABB4)
    static let salvageBackground = adaptive(light: 0xFDE7EB, dark: 0x47242D)
    static let otherTitle = adaptive(light: 0x69419A, dark: 0xD8BCFF)
    static let otherTitleBackground = adaptive(light: 0xF0E8FA, dark: 0x352846)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                           green: CGFloat((rgb >> 8) & 0xFF) / 255,
                           blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
        })
    }
    static let background = LinearGradient(
        colors: [mist, Color(uiColor: .systemGroupedBackground), mist.opacity(0.65)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

struct CoastalVehicleInventoryRow: View {
    let vehicle: Vehicle
    let bidState: BidState
    let isSaved: Bool
    let toggleWatchlist: () -> Void
    let reviewBid: () -> Void
    var navigationAccessibilityIdentifier: String? = nil
    var userBid: Int? = nil

    // A fresh Date.now in body would reschedule the timeline during layout.
    @State private var timelineOrigin = Date.now

    var body: some View {
        TimelineView(.explicit(AuctionSchedule(vehicle: vehicle)?.timelineDates(from: timelineOrigin) ?? [timelineOrigin])) { context in
            card(at: context.date)
        }
    }

    private func card(at now: Date) -> some View {
        let isLive = AuctionSchedule(vehicle: vehicle)?.status(at: now) == .live
        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                NavigationLink(value: vehicle.id) {
                    VStack(alignment: .leading, spacing: 14) {
                        heading.padding(.trailing, 54)
                        HStack(alignment: .center, spacing: 14) {
                            photo
                            details
                        }
                    }
                    .padding(18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .accessibilityIdentifier(navigationAccessibilityIdentifier ?? "vehicle-\(vehicle.lot)")

                VehicleWatchlistButton(vehicle: vehicle, isSaved: isSaved, toggle: toggleWatchlist)
                    .background(InventoryPalette.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(InventoryPalette.navy.opacity(0.12), lineWidth: 1)
                    }
                    .padding(18)
            }
            VStack(spacing: 14) {
                Divider()
                HStack(spacing: 12) {
                    bid
                    Spacer(minLength: 0)
                    Button(action: reviewBid) {
                        HStack(spacing: 6) {
                            Text(userBid == nil ? "Place bid" : "Raise bid")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(InventoryPalette.navy, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(InventoryPalette.card)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!isLive)
                    .opacity(isLive ? 1 : 0.45)
                    .accessibilityIdentifier("inventoryBid-\(vehicle.lot)")
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            AuctionStatusFooter(vehicle: vehicle, now: now)
        }
        .foregroundStyle(InventoryPalette.navy)
        .background(InventoryPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(InventoryPalette.navy.opacity(0.10), lineWidth: 1)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: VehicleDisplayFormatter.identity(vehicle))
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.5)
            Text("\(vehicle.trim) · \(vehicle.engine) · \(vehicle.drivetrain)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photo: some View {
        VehicleImage(url: vehicle.images.first, requiresScrollVisibility: true)
            .frame(width: 112, height: 108)
            .background(InventoryPalette.mist)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(alignment: .topTrailing) {
                Label(vehicle.images.count.formatted(), systemImage: "photo.on.rectangle")
                    .font(.system(size: 11))
                    .padding(5)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                    .padding(5)
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(vehicle.odometerKm.formatted()) km")
                .font(.system(size: 16, weight: .semibold))
            Label("\(vehicle.city), \(province)", systemImage: "mappin.and.ellipse")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) { lotBadge; titleBadge }
            Text("Condition \(vehicle.conditionGrade.formatted(.number.precision(.fractionLength(1))))/5")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var province: String {
        ["Alberta": "AB", "British Columbia": "BC", "Manitoba": "MB",
         "New Brunswick": "NB", "Newfoundland and Labrador": "NL", "Northwest Territories": "NT",
         "Nova Scotia": "NS", "Nunavut": "NU", "Ontario": "ON", "Prince Edward Island": "PE",
         "Quebec": "QC", "Saskatchewan": "SK", "Yukon": "YT"][vehicle.province] ?? vehicle.province
    }

    private var lotBadge: some View {
        Text("LOT \(vehicle.lot)")
            .tracking(0.3)
            .foregroundStyle(.white)
            .modifier(InventoryBadgeStyle(fill: InventoryPalette.lotNavy))
    }

    private var titleBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: titlePresentation.icon)
            Text(titlePresentation.text)
        }
        .foregroundStyle(titlePresentation.color)
        .modifier(InventoryBadgeStyle(fill: titlePresentation.background))
    }

    private var titlePresentation: (text: String, icon: String, color: Color, background: Color) {
        switch vehicle.titleStatus {
        case "clean": (String(localized: "Clean title"), "checkmark.shield", InventoryPalette.cleanTitle, InventoryPalette.mist)
        case "rebuilt": (String(localized: "Rebuilt title"), "wrench.and.screwdriver", InventoryPalette.rebuiltTitle, InventoryPalette.rebuiltBackground)
        case "salvage": (String(localized: "Salvage title"), "exclamationmark.triangle", InventoryPalette.salvageTitle, InventoryPalette.salvageBackground)
        default: ("Title: \(vehicle.titleStatus)", "doc.text", InventoryPalette.otherTitle, InventoryPalette.otherTitleBackground)
        }
    }

    private var bid: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(bidState.currentBid == nil ? "STARTING BID" : "CURRENT BID")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text((bidState.currentBid ?? vehicle.startingBid).formatted(
                    .currency(code: "CAD").presentation(.narrow).precision(.fractionLength(0))))
                    .font(.system(size: 29, weight: .semibold))
                    .tracking(-1)
                    .monospacedDigit()
                Text("CAD").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if let userBid {
                Text("Your latest bid · \(VehicleDisplayFormatter.money(userBid))")
                    .font(.system(size: 12, weight: .semibold))
            }
            Text("\(bidState.bidCount) bids · \(reserveLabel)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var reserveLabel: String {
        switch BidPolicy().reserve(for: vehicle, state: bidState) {
        case .noReserve: String(localized: "No reserve")
        case .notMet: String(localized: "Reserve not met")
        case .met: String(localized: "Reserve met")
        }
    }

}

private struct InventoryBadgeStyle: ViewModifier {
    let fill: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .semibold))
            .imageScale(.small)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(fill, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Source timestamps have no zone. Format their wall-clock components without shifting them.
enum InventoryAuctionTime {
    static func display(_ source: String, locale: Locale = .current) -> String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        parser.isLenient = false
        guard let date = parser.date(from: source), parser.string(from: date) == source else { return nil }
        let display = DateFormatter()
        display.locale = locale
        display.timeZone = parser.timeZone
        display.dateFormat = "MMM d · HH:mm"
        return display.string(from: date)
    }
}
