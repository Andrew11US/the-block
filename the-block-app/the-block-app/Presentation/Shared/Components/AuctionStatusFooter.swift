import SwiftUI

struct AuctionStatusFooter: View {
    let vehicle: Vehicle
    let now: Date
    let showsTopDivider: Bool
    let showsSeconds: Bool

    private let schedule: AuctionSchedule?
    // A fresh Date.now in body would reschedule the timeline during layout.
    @State private var timelineOrigin = Date.now

    init(vehicle: Vehicle, now: Date, showsTopDivider: Bool = true, showsSeconds: Bool = false) {
        self.vehicle = vehicle
        self.now = now
        self.showsTopDivider = showsTopDivider
        self.showsSeconds = showsSeconds
        schedule = AuctionSchedule(vehicle: vehicle)
    }

    var body: some View {
        // Keep periodic updates local to the footer; only detail opts into seconds.
        // Parent timelines still update status at exact auction boundaries.
        if let schedule, now < schedule.end {
            TimelineView(.periodic(from: timelineOrigin, by: showsSeconds ? 1 : 60)) { context in
                footer(at: context.date)
            }
        } else {
            footer(at: now)
        }
    }

    private func footer(at date: Date) -> some View {
        // Reuse parsed dates rather than constructing DateFormatters on every tick.
        AuctionFooterContent(schedule: schedule, now: date, showsTopDivider: showsTopDivider,
                             showsSeconds: showsSeconds)
    }
}

private struct AuctionFooterContent: View {
    let schedule: AuctionSchedule?
    let now: Date
    let showsTopDivider: Bool
    let showsSeconds: Bool

    private var status: AuctionStatus? { schedule?.status(at: now) }
    private var color: Color {
        switch status {
        case .live: InventoryPalette.cleanTitle
        case .ended: InventoryPalette.salvageTitle
        default: InventoryPalette.navy
        }
    }
    private var fill: Color {
        switch status {
        case .live: InventoryPalette.liveBackground
        case .ended: InventoryPalette.salvageBackground
        default: InventoryPalette.mist
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            statusLabel
            Spacer(minLength: 0)
            timing
        }
        .font(.system(size: 12))
        .foregroundStyle(color)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(fill)
        .overlay(alignment: .top) {
            if showsTopDivider { Divider() }
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch status {
        case .live: Label("Live auction", systemImage: "dot.radiowaves.left.and.right")
        case .upcoming: Label("Upcoming", systemImage: "clock")
        case .ended: Label("Auction ended", systemImage: "flag.checkered")
        case nil: Label("Schedule unavailable", systemImage: "exclamationmark.circle")
        }
    }

    @ViewBuilder private var timing: some View {
        if let schedule {
            switch schedule.status(at: now) {
            case .live:
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                    Text("Ends in")
                    Text(remaining(until: schedule.end))
                        .monospacedDigit()
                        .fixedSize()
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.12), in: Capsule())
                .fixedSize(horizontal: true, vertical: false)
            case .upcoming:
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Starts \(schedule.start.formatted(date: .abbreviated, time: .shortened))")
                    HStack(spacing: 4) {
                        Text("Starts in")
                        Text(remaining(until: schedule.start))
                            .monospacedDigit()
                            .fixedSize()
                    }
                }
            case .ended:
                Text(schedule.end, format: .dateTime.month(.abbreviated).day().hour().minute())
            }
        }
    }

    private func remaining(until date: Date) -> String {
        if showsSeconds {
            let seconds = Int(max(0, ceil(date.timeIntervalSince(now))))
            return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        let minutes = Int(max(0, ceil(date.timeIntervalSince(now) / 60)))
        return String(format: "%02dh %02dm", minutes / 60, minutes % 60)
    }
}
