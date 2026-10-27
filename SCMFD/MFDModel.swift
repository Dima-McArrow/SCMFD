import Foundation
import Observation

enum MFDPage: String, CaseIterable, Identifiable {
    case mission
    case credits

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mission: "Mission Control"
        case .credits: "Credit Recorder"
        }
    }

    var shortTitle: String {
        switch self {
        case .mission: "Missions"
        case .credits: "Finances"
        }
    }

    var symbol: String {
        switch self {
        case .mission: "shippingbox"
        case .credits: "list.bullet.rectangle"
        }
    }

    var number: String {
        switch self {
        case .mission: "01"
        case .credits: "02"
        }
    }
}

struct DeliveryObjective: Identifiable {
    let id: String
    let destination: String
    let commodity: String
    let requiredSCU: Int
}

struct CreditEntry: Identifiable {
    let id: String
    let time: String
    let title: String
    let amount: Int
    let source: String
}

@Observable
final class DemoSession {
    private(set) var missionAbandoned = false
    private(set) var includesFine = false

    // These objectives belong to the same captured contract; they are not cargo telemetry.
    let objectives = [
        DeliveryObjective(
            id: "dropoff_0",
            destination: "HDPC-Cassillo",
            commodity: "Pressurized Ice",
            requiredSCU: 13
        ),
        DeliveryObjective(
            id: "dropoff_1",
            destination: "Teasa Spaceport",
            commodity: "Food",
            requiredSCU: 188
        ),
    ]

    var requiredSCU: Int {
        objectives.reduce(0) { $0 + $1.requiredSCU }
    }

    var creditEntries: [CreditEntry] {
        var entries = [
            CreditEntry(
                id: "reward",
                time: "22:09:03",
                title: "Reward received",
                amount: 28_375,
                source: "Reward notification"
            )
        ]
        if includesFine {
            entries.append(
                CreditEntry(
                    id: "fine",
                    time: "21:17:46",
                    title: "Fine recorded",
                    amount: -20_000,
                    source: "Fine notification"
                )
            )
        }
        return entries
    }

    var recordedCreditDelta: Int {
        creditEntries.reduce(0) { $0 + $1.amount }
    }

    func replayAbandonment() {
        missionAbandoned = true
    }

    func replayAcceptance() {
        missionAbandoned = false
    }

    func toggleFine() {
        includesFine.toggle()
    }

    func reset() {
        missionAbandoned = false
        includesFine = false
    }
}

enum MFDFormat {
    static func integer(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US")))
    }

    static func signed(_ value: Int) -> String {
        (value >= 0 ? "+" : "−") + integer(abs(value))
    }
}
