# House Rockets

- Primary target: `Views/Discover/Games/HouseRockets/HouseRocketsView.swift`
- Related: `HouseRocketsScene.swift`, `HouseRocketsArtwork.swift`, `Views/Discover/GamesHubView.swift`.
- Mode: Experience. Preserve continuous thrust, floating edge joystick, course geometry and game rules.
- Approved reference: user-supplied rocket.png; round hull, round porthole, swept fins and rear collar. Use the shared vector contours for ships and the Games card.
- Palette: burgundy #780000, red #C1121F, cream #FDF0D5, navy #003049, blue #669BBC, ice #A9D6E5.
- Navy base; cream text and collision edges; burgundy obstacles; blue boost and red slow tokens with distinct symbols.
- Static abstract topographic waves mix blue, ice, burgundy, red and cream contours in the outer blue base, with soft broad color traces behind selected lines. Cream/ice contours remain clipped inside burgundy obstacles. The solid navy course contrasts with the outer base; no busy motion behind the game.
- Extend the course to the physical left/right edges when horizontal and top/bottom edges when vertical, keeping the HUD in the opposite empty margins. Hide informational HUD throughout each three-second turn. Keep pause available. Vertical HUD sits at the top of the left/right empty margins; horizontal HUD uses top/bottom margins.
