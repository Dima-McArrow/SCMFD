import Foundation
import Testing
@testable import SCMFD

/// FIX-08: readable names for the quantum target names in Game.log (41.8).
struct QuantumTargetNameTests {
    /// Generic labels follow the device language, so the expected value comes from the same catalog key.
    nonisolated static let missionBeacon = String(localized: "Mission beacon")
    nonisolated static let navMarker = String(localized: "Nav marker")
    nonisolated static let parkedVehicle = String(localized: "Parked vehicle")
    nonisolated static let restStop = String(localized: "Rest stop")

    /// Every example of the FIX-08 tables, as seen in the owner's logs.
    nonisolated static let knownNames: [(String, String)] = [
        // Exact table.
        ("ObjectContainer_Lorville_City", "Lorville"),
        ("Area18_City_objectContainer", "Area18"),
        ("NewBabbage_LOC", "New Babbage"),
        ("Orison_LOC", "Orison"),
        ("levski_all-001", "Levski"),
        ("ObjectContainer_RestStop", restStop),
        // Planets and moons.
        ("OOC_Stanton_1_Hurston", "Hurston"),
        ("OOC_Stanton_1b_Aberdeen", "Aberdeen"),
        ("OOC_Stanton_2b_Daymar", "Daymar"),
        // Stanton Lagrange rest stops.
        ("LOC_RR_S1_L3", "HUR-L3"),
        ("LOC_RR_S2_L4", "CRU-L4"),
        ("LOC_RR_S3_L1", "ARC-L1"),
        // Jump point stations.
        ("LOC_rs_ext_stan-pyro_jp1", "Pyro Gateway"),
        ("rs_ext_pyro-stan_jp1", "Stanton Gateway"),
        ("rs_ext_nyx-castra_jp1", "Castra Gateway"),
        // Pyro planets.
        ("pyro2", "Pyro II"),
        ("pyro3", "Pyro III"),
        // Unconfirmed Pyro stations: a rule-based label, never the guessed station name.
        ("rs_ext_pyro6_l5", "Pyro VI · L5"),
        ("rs_ext_pyro2_l4", "Pyro II · L4"),
        ("rs_ext_pyro3_leo", String(localized: "\("Pyro III") · orbit station")),
        // Markers.
        ("MISSION_QT_Quantum_Beacon_LongRange_865021957216", missionBeacon),
        ("NavPoint_Dynamic_876079337427", navMarker),
        ("UnattendedVehicleMarker_888984011374", parkedVehicle),
    ]

    @Test(arguments: knownNames)
    func knownNameIsReadable(internalName: String, expected: String) {
        #expect(QuantumTargetName.display(for: internalName) == expected)
    }

    /// Names without a reliable meaning stay raw, and so do near misses of the rules.
    nonisolated static let unknownNames = [
        "rayari_cluster_001_dust_{90B48360-1D2C-4E5F-8A9B-0C1D2E3F4A5B}.socpak",
        "social_001_keeger_segment_rckcrk_095",
        "glaciemring_TransitPoint_Bravo",
        "P1_L3",
        "LOC_RR_S5_L1",
        "rs_ext_stan-unknown_jp1",
        "pyro7",
        "rs_ext_pyro6_orbit",
        "NavPoint_Dynamic_",
        "",
    ]

    @Test(arguments: unknownNames)
    func unknownNameIsNotInvented(internalName: String) {
        #expect(QuantumTargetName.display(for: internalName) == nil)
    }

    @Test func microtechKeepsTheBrandCasing() {
        #expect(QuantumTargetName.display(for: "OOC_Stanton_4_Microtech") == "microTech")
    }

    @Test func serverDisplayNameWinsOverTheTable() {
        let status = QuantumTargetStatus(mode: .destination, internalName: "OOC_Stanton_1_Hurston",
                                         displayName: "Hurston (server)", confidence: .confirmed, observedAt: nil)
        #expect(QuantumTarget(status) == .destination("Hurston (server)"))
    }

    @Test func readoutUsesTheTableWithoutADisplayName() {
        let status = QuantumTargetStatus(mode: .destination, internalName: "LOC_RR_S2_L4",
                                         displayName: nil, confidence: .confirmed, observedAt: nil)
        #expect(QuantumTarget(status) == .destination("CRU-L4"))
    }
}
