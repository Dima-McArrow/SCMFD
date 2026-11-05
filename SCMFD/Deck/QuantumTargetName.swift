import Foundation

/// Readable names for the technical quantum target names in Game.log (FIX-08). The UI prefers a server
/// `displayName` (41.8); this lookup fills in when there is none.
///
/// Order: the exact table, then the rules, then nil, so the readout keeps the raw name. A name is never
/// guessed: Pyro stations that are not confirmed in game get a rule-based label, not a station name.
/// Place names are proper nouns and are not localized; generic labels are.
nonisolated enum QuantumTargetName {
    static func display(for internalName: String) -> String? {
        if let name = exact(internalName) { return name }
        return rule(internalName)
    }

    // MARK: - Exact table (seen in the logs)

    private static func exact(_ name: String) -> String? {
        switch name {
        case "ObjectContainer_Lorville_City": "Lorville"
        case "Area18_City_objectContainer": "Area18"
        case "NewBabbage_LOC": "New Babbage"
        case "Orison_LOC": "Orison"
        case "levski_all-001": "Levski"
        // The log does not say which rest stop it is.
        case "ObjectContainer_RestStop": String(localized: "Rest stop", comment: "Quantum target: an unnamed rest stop")
        default: nil
        }
    }

    // MARK: - Rules

    private static func rule(_ name: String) -> String? {
        if let match = name.wholeMatch(of: #/OOC_Stanton_[0-9]+[a-z]?_([A-Za-z0-9]+)/#) {
            let body = String(match.1)
            // The log writes "Microtech"; the brand is "microTech".
            return body == "Microtech" ? "microTech" : body
        }
        if let match = name.wholeMatch(of: #/LOC_RR_S([0-9]+)_L([0-9]+)/#),
           let planet = Int(match.1), stantonRestStopPrefixes.indices.contains(planet - 1) {
            return "\(stantonRestStopPrefixes[planet - 1])-L\(match.2)"
        }
        if let match = name.wholeMatch(of: #/(?:LOC_)?rs_ext_([a-z]+)-([a-z]+)_jp1?/#),
           systems[String(match.1)] != nil, let destination = systems[String(match.2)] {
            return "\(destination) Gateway"
        }
        if let match = name.wholeMatch(of: #/rs_ext_pyro([0-9]+)_(l[0-9]+|leo)/#),
           let planet = pyroPlanet(match.1) {
            // Station names are not confirmed yet (FIX-08 section 3): a rule-based label only.
            if match.2 == "leo" {
                return String(localized: "\(planet) · orbit station",
                              comment: "Quantum target: an unconfirmed station orbiting a planet, e.g. Pyro III")
            }
            return "\(planet) · L\(match.2.dropFirst())"
        }
        if let match = name.wholeMatch(of: #/pyro([0-9]+)/#), let planet = pyroPlanet(match.1) {
            return planet
        }
        if name.hasPrefix("MISSION_QT_") {
            return String(localized: "Mission beacon", comment: "Quantum target: a mission quantum beacon")
        }
        if name.wholeMatch(of: #/NavPoint_Dynamic_[0-9]+/#) != nil {
            return String(localized: "Nav marker", comment: "Quantum target: a dynamic navigation marker")
        }
        if name.wholeMatch(of: #/UnattendedVehicleMarker_[0-9]+/#) != nil {
            return String(localized: "Parked vehicle", comment: "Quantum target: the player's unattended vehicle")
        }
        return nil
    }

    /// Stanton I…IV: Hurston, Crusader, ArcCorp, microTech.
    private static let stantonRestStopPrefixes = ["HUR", "CRU", "ARC", "MIC"]

    private static let systems = [
        "stan": "Stanton", "pyro": "Pyro", "nyx": "Nyx", "castra": "Castra", "magnus": "Magnus", "terra": "Terra",
    ]

    /// "Pyro I" … "Pyro VI"; nil for a planet Pyro does not have.
    private static func pyroPlanet(_ digits: Substring) -> String? {
        let numerals = ["I", "II", "III", "IV", "V", "VI"]
        guard let number = Int(digits), numerals.indices.contains(number - 1) else { return nil }
        return "Pyro \(numerals[number - 1])"
    }
}
