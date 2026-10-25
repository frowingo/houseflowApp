// Generated from Fixtures/houseTanksMaps.json by Scripts/generate_house_tanks_maps.py.
// Do not edit: the backend owns the catalog; copy its fixture and run the script again.

extension HouseTanksMapCatalog {
    public static let catalogVersion = 2
    public static let contractRevision = "houseTanks.v2"

    /// Every map in authored order; online play draws among those that seat the roster.
    public static let maps: [HouseTanksMapDefinition] = [livingRoom, corridors, warehouse, courtyard, basement]

    public static let livingRoom = HouseTanksMapDefinition(
        id: .livingRoom,
        version: 3,
        spawnPoints: [point(0.1, 0.36), point(0.88, 0.22), point(0.88, 0.64), point(0.12, 0.7), point(0.5, 0.12)],
        obstacles: [
            obstacle(0.5, 0.5, 0.07, 0.28, .divider, .navy),
            obstacle(0.31, 0.3, 0.18, 0.075, .sofa, .teal, rotation: 0.04),
            obstacle(0.69, 0.7, 0.18, 0.075, .sofa, .orange, rotation: -0.04),
            obstacle(0.3, 0.72, 0.12, 0.12, .roundTable, .blue),
            obstacle(0.7, 0.28, 0.1, 0.1, .crate, .wood, rotation: 0.2617993877991494),
            obstacle(0.15, 0.2, 0.12, 0.055, .bookshelf, .navy),
            obstacle(0.85, 0.8, 0.09, 0.09, .planter, .green),
            obstacle(0.4, 0.56, 0.12, 0.12, .crate, .wood),
            obstacle(0.6, 0.4, 0.12, 0.12, .crate, .wood),
            obstacle(0.42, 0.83, 0.12, 0.12, .crate, .wood),
        ],
        floorLines: [line(0.1, 0.5, 0.28, 0.5), line(0.28, 0.5, 0.28, 0.78), line(0.72, 0.22, 0.72, 0.5), line(0.72, 0.5, 0.9, 0.5)],
        floorMarkers: [point(0.12, 0.2), point(0.88, 0.8), point(0.5, 0.12), point(0.5, 0.88)],
        scale: 1,
        minPlayers: 2,
        maxPlayers: 5
    )

    public static let corridors = HouseTanksMapDefinition(
        id: .corridors,
        version: 3,
        spawnPoints: [point(0.12, 0.24), point(0.88, 0.7), point(0.88, 0.24), point(0.12, 0.7), point(0.41, 0.66)],
        obstacles: [
            obstacle(0.3, 0.36, 0.055, 1.25, .divider, .navy),
            obstacle(0.35, 0.14, 0.3, 0.055, .divider, .navy),
            obstacle(0.51, 0.64, 0.055, 1.25, .divider, .blue),
            obstacle(0.56, 0.86, 0.3, 0.055, .divider, .blue),
            obstacle(0.72, 0.36, 0.055, 1.25, .divider, .navy),
            obstacle(0.67, 0.14, 0.3, 0.055, .divider, .navy),
            obstacle(0.3, 0.7, 0.12, 0.12, .crate, .wood),
            obstacle(0.51, 0.28, 0.12, 0.12, .crate, .wood),
            obstacle(0.72, 0.71, 0.12, 0.12, .crate, .wood),
            obstacle(0.4, 0.46, 0.1, 0.1, .crate, .wood),
        ],
        floorLines: [line(0.12, 0.34, 0.88, 0.34), line(0.12, 0.66, 0.88, 0.66), line(0.5, 0.1, 0.5, 0.9)],
        floorMarkers: [point(0.12, 0.12), point(0.88, 0.12), point(0.12, 0.88), point(0.88, 0.88)],
        scale: 1,
        minPlayers: 2,
        maxPlayers: 5
    )

    public static let warehouse = HouseTanksMapDefinition(
        id: .warehouse,
        version: 3,
        spawnPoints: [point(0.1, 0.36), point(0.9, 0.64), point(0.9, 0.24), point(0.1, 0.7), point(0.4, 0.5)],
        obstacles: [
            obstacle(0.28, 0.24, 0.1, 0.1, .crate, .wood, rotation: 0.1),
            obstacle(0.38, 0.3, 0.08, 0.08, .crate, .wood, rotation: -0.06),
            obstacle(0.3, 0.72, 0.08, 0.08, .crate, .wood),
            obstacle(0.4, 0.66, 0.11, 0.11, .crate, .orange, rotation: 0.08),
            obstacle(0.35, 0.18, 0.72, 0.08, .bookshelf, .navy),
            obstacle(0.65, 0.36, 0.72, 0.08, .bookshelf, .navy),
            obstacle(0.35, 0.82, 0.72, 0.08, .bookshelf, .navy),
            obstacle(0.65, 0.64, 0.72, 0.08, .bookshelf, .navy),
            obstacle(0.72, 0.46, 0.12, 0.12, .crate, .wood),
            obstacle(0.76, 0.76, 0.12, 0.12, .crate, .wood, rotation: 0.12),
            obstacle(0.2, 0.14, 0.075, 0.075, .pillar, .teal),
            obstacle(0.2, 0.86, 0.075, 0.075, .pillar, .teal),
            obstacle(0.88, 0.5, 0.08, 0.08, .planter, .green),
            obstacle(0.48, 0.38, 0.07, 0.07, .crate, .orange),
            obstacle(0.48, 0.62, 0.07, 0.07, .crate, .orange),
        ],
        floorLines: [line(0.12, 0.16, 0.88, 0.16), line(0.12, 0.84, 0.88, 0.84), line(0.18, 0.5, 0.82, 0.5)],
        floorMarkers: [point(0.1, 0.3), point(0.1, 0.7), point(0.9, 0.3), point(0.9, 0.7)],
        scale: 1,
        minPlayers: 2,
        maxPlayers: 5
    )

    public static let courtyard = HouseTanksMapDefinition(
        id: .courtyard,
        version: 4,
        spawnPoints: [point(0.12, 0.36), point(0.88, 0.64), point(0.86, 0.22), point(0.14, 0.7), point(0.4, 0.08)],
        obstacles: [
            obstacle(0.5, 0.5, 0.18, 0.18, .roundTable, .teal),
            obstacle(0.5, 0.26, 0.7, 0.07, .divider, .green),
            obstacle(0.5, 0.74, 0.7, 0.07, .divider, .green),
            obstacle(0.32, 0.5, 0.045, 0.7, .divider, .green),
            obstacle(0.68, 0.5, 0.045, 0.7, .divider, .green),
            obstacle(0.5, 0.16, 0.1, 0.1, .planter, .green),
            obstacle(0.5, 0.84, 0.1, 0.1, .planter, .green),
            obstacle(0.16, 0.18, 0.11, 0.055, .sofa, .blue, rotation: 0.08),
            obstacle(0.84, 0.5, 0.11, 0.055, .sofa, .orange, rotation: 1.5707963267948966),
            obstacle(0.38, 0.38, 0.12, 0.12, .crate, .wood),
            obstacle(0.62, 0.62, 0.12, 0.12, .crate, .wood),
            obstacle(0.51, 0.6, 0.1, 0.1, .crate, .wood),
        ],
        floorLines: [line(0.18, 0.5, 0.38, 0.5), line(0.62, 0.5, 0.88, 0.5), line(0.5, 0.12, 0.5, 0.38), line(0.5, 0.62, 0.5, 0.88)],
        floorMarkers: [point(0.18, 0.18), point(0.82, 0.18), point(0.18, 0.82), point(0.82, 0.82)],
        scale: 1,
        minPlayers: 2,
        maxPlayers: 5
    )

    public static let basement = HouseTanksMapDefinition(
        id: .basement,
        version: 1,
        spawnPoints: [point(0.07, 0.4), point(0.93, 0.4), point(0.07, 0.68), point(0.93, 0.68), point(0.07, 0.12), point(0.93, 0.12), point(0.36, 0.08), point(0.64, 0.08)],
        obstacles: [
            obstacle(0.24, 0.5, 0.05, 0.95, .divider, .navy),
            obstacle(0.76, 0.5, 0.05, 0.95, .divider, .navy),
            obstacle(0.5, 0.8, 0.42, 0.06, .divider, .blue),
            obstacle(0.5, 0.24, 0.3, 0.06, .divider, .blue),
            obstacle(0.38, 0.64, 0.26, 0.06, .bookshelf, .navy),
            obstacle(0.62, 0.36, 0.26, 0.06, .bookshelf, .navy),
            obstacle(0.5, 0.5, 0.14, 0.14, .roundTable, .teal),
            obstacle(0.15, 0.26, 0.07, 0.07, .pillar, .teal),
            obstacle(0.85, 0.26, 0.07, 0.07, .pillar, .teal),
            obstacle(0.15, 0.84, 0.07, 0.07, .pillar, .teal),
            obstacle(0.85, 0.84, 0.07, 0.07, .pillar, .teal),
            obstacle(0.4, 0.9, 0.08, 0.08, .planter, .green),
            obstacle(0.6, 0.9, 0.08, 0.08, .planter, .green),
            obstacle(0.15, 0.55, 0.12, 0.055, .sofa, .orange, rotation: 1.5707963267948966),
            obstacle(0.85, 0.55, 0.12, 0.055, .sofa, .orange, rotation: 1.5707963267948966),
            obstacle(0.38, 0.4, 0.11, 0.11, .crate, .wood),
            obstacle(0.62, 0.6, 0.11, 0.11, .crate, .wood),
            obstacle(0.5, 0.64, 0.1, 0.1, .crate, .wood, rotation: 0.2617993877991494),
            obstacle(0.44, 0.14, 0.1, 0.1, .crate, .wood),
            obstacle(0.56, 0.14, 0.1, 0.1, .crate, .wood),
            obstacle(0.32, 0.88, 0.1, 0.1, .crate, .wood),
            obstacle(0.68, 0.88, 0.1, 0.1, .crate, .wood),
        ],
        floorLines: [line(0.1, 0.5, 0.2, 0.5), line(0.8, 0.5, 0.9, 0.5), line(0.3, 0.24, 0.3, 0.76), line(0.7, 0.24, 0.7, 0.76)],
        floorMarkers: [point(0.5, 0.08), point(0.5, 0.92), point(0.12, 0.92), point(0.88, 0.92)],
        scale: 0.72,
        minPlayers: 6,
        maxPlayers: 8
    )
}
