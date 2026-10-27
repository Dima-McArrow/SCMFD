import Foundation
import Observation

enum MFDPage: String, CaseIterable, Identifiable {
    case mission
    case credits
    case terminal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mission: "Mission Control"
        case .credits: "Credit Recorder"
        case .terminal: "Command Terminal"
        }
    }

    var shortTitle: String {
        switch self {
        case .mission: "Missions"
        case .credits: "Finances"
        case .terminal: "Terminal"
        }
    }

    var symbol: String {
        switch self {
        case .mission: "shippingbox"
        case .credits: "list.bullet.rectangle"
        case .terminal: "terminal"
        }
    }

    var number: String {
        switch self {
        case .mission: "01"
        case .credits: "02"
        case .terminal: "03"
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

enum ShipCommand: String, CaseIterable, Identifiable {
    case requestLanding
    case toggleGear
    case toggleLights
    case closeDoors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .requestLanding: "Запрос посадки"
        case .toggleGear: "Переключить шасси"
        case .toggleLights: "Переключить свет"
        case .closeDoors: "Закрыть двери"
        }
    }

    var symbol: String {
        switch self {
        case .requestLanding: "antenna.radiowaves.left.and.right"
        case .toggleGear: "airplane.arrival"
        case .toggleLights: "lightbulb"
        case .closeDoors: "door.left.hand.closed"
        }
    }

    var code: String {
        switch self {
        case .requestLanding: "ATC_REQUEST"
        case .toggleGear: "GEAR_TOGGLE"
        case .toggleLights: "LIGHTS_TOGGLE"
        case .closeDoors: "DOORS_CLOSE"
        }
    }
}

struct CommandReceipt: Identifiable {
    let id: Int
    let command: ShipCommand
}

@Observable
final class DemoSession {
    private(set) var missionAbandoned = false
    private(set) var includesFine = false
    private(set) var receipts: [CommandReceipt] = []
    private var nextReceiptID = 1

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

    func sendDemoCommand(_ command: ShipCommand) {
        // A local receipt confirms only the simulation, never execution by the game.
        receipts.insert(CommandReceipt(id: nextReceiptID, command: command), at: 0)
        nextReceiptID += 1
        receipts = Array(receipts.prefix(6))
    }

    func reset() {
        missionAbandoned = false
        includesFine = false
        receipts = []
        nextReceiptID = 1
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
