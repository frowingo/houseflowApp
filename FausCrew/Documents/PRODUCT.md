# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

FausCrew is used by members of a shared household. Repository evidence shows that members manage a home, chores, profiles, and lightweight games in the same app. The exact audience demographics remain open.

## Product Purpose

FausCrew brings recurring household coordination and small social moments into one native app. Success means household members can understand their responsibilities quickly and return for lightweight shared interactions without leaving the household context.

## Operating Context

- Native iPhone and iPad app built with SwiftUI.
- Authenticated members belong to one or more houses.
- Games are discovered from the Games tab and open as focused experiences inside the existing navigation stack.
- Localization is supplied by the app's localization service, with local fallback behavior where implemented.

## Capabilities and Constraints

- Existing games include solo arcade and group-oriented experiences.
- House Rockets is a separate landscape demo with one human player per screen and one to three local bots. A floating 360° joystick can be started in either outer 30% of the safe playfield, appearing translucently only while dragging and hiding on release; every ship has continuous propulsion at a shared base speed of 300 world units/second and retains its heading when input ends. Smaller fields oscillating across the course at fixed forward positions briefly boost speed by 45% for 1.3 seconds or slow it by 35% for 1.4 seconds; each ship can trigger each field once. Small ships navigate stationary solid obstacles with narrowing, widening, sloping and hourglass passages; contact blocks or slides without eliminating. The camera advances with the leading ship and never retreats. Every 25 seconds the course starts a three-second turn, alternating upward and rightward travel while the device stays landscape; screen-relative steering and the same collision rules apply. Only completely crossing the rear edge (left in horizontal travel, bottom in vertical travel) eliminates a ship; the last survivor wins, with no time limit. A later multiplayer phase connects separate players online, with one human control per device.
- House Rockets uses the supplied rounded rocket reference with a circular window and swept fins, shared across gameplay and its Games card. The Games card retains the shared card layout. Its palette is #780000, #C1121F, #FDF0D5, #003049, #669BBC and #A9D6E5. A uniform camera zoom enlarges the course, rockets, obstacles and tokens together. The navy course sits on a distinct blue background with subdued blue, burgundy, red and cream topographic contours in the outside areas, plus contours inside obstacles. The course extends to the physical left/right screen edges in horizontal mode and top/bottom edges in vertical mode. Information hides during course turns and returns at the top of the side margins in vertical mode; pause stays available.
- Lucky Spin is a household turn-selection tool rather than a casino simulation. The name shown in the result must always match the wheel segment under the fixed top pointer.
- Rock-Paper-Scissors is presented as a household tabletop tournament: match, round, and tournament-board language replaces arena framing, while the move art uses authored shapes instead of emoji.
- House-Tanks is a separate landscape-only game. Its demo is one human against two bots, with one player per device rather than shared on-screen controls.
- House-Tanks uses press-and-hold movement: tanks rotate automatically while idle, lock their firing angle on touch-down, fire once, and move forward in that direction until the touch ends. Every return to idle rotation reverses the tank's previous rotation direction.
- Each House-Tanks player starts a round with five armor points. A round lasts at most 60 seconds; the last survivor or the unique highest-armor player wins. The match ends at three round wins.
- House-Tanks keeps its future online boundary explicit through commands and revisioned snapshots, but the demo does not include networking, matchmaking, or server authority.
- House-Tanks must use original household tabletop visuals and sounds rather than copying the reference game's assets.
- Faus Switch (formerly House-Switch) is a landscape gravity race with a demo mode and an online multiplayer mode, split the same way as Faus Tanks and House Rockets: the player picks Demo or Online in a portrait lobby, and the race turns the screen to landscape.
- Demo: one human against one to three local bots (Volt, Byte, Pixel) on the device, no network. Online: everyone in the house who is ready races the same server-authoritative course; the server owns flips, crashes, finish order and the persisted result. One robot per device.
- Each player picks a robot color (eight colors). In demo the bots take the remaining colors; online, the first player to claim a color keeps it and the others get a free color.
- Leaving Faus Tanks or Faus Switch returns the Games screen to portrait orientation.
- The course scrolls forward continuously. Hitting a solid obstacle does not pause that movement; a runner that fully leaves the left edge is eliminated.
- Obstacles come in groups of two or three that split the screen into passages, alternating between top, bottom and middle, instead of single columns from only the top or only the bottom. Floor and ceiling gaps send a runner off-screen; small one-use speed pads give a brief forward gain; one-use slow pads in awkward spots (landings after gaps, rails a runner must leave before a block) cost a little ground; portals on the floor or ceiling, just big enough for a robot, send a runner to the opposite rail and farther back (never behind the camera's edge).
- A tap reverses gravity only while the runner's feet are supported by solid geometry. Mid-air taps are ignored. Platform contact is never lethal.
- The physics (run speed, gravity, flip velocity, boost and gap behavior) are unchanged from the original game and now run as a deterministic 120 Hz simulation in FausCrewCore so the server can run the same rules.
- The race HUD has no progress bar and no flip counter; it shows pause (demo) or leave (online) and small live standings.
- Faus Switch must not copy the reference game's name, artwork, or proprietary assets.
- Project changes must not be committed without a commit message supplied by the user.

## Brand Commitments

- Preserve the FausCrew name and the app's existing friendly, rounded, colorful native character.
- The gravity race is named **Faus Switch**.
- Gameplay may be more immersive and energetic than utility screens, while navigation and controls remain recognizably native to the app.

## Evidence on Hand

- Reference recording: `/Users/frowing/Documents/SS/Ekran Kaydı 2026-09-20 23.04.40.mov`.
- House-Tanks reference recording: `/Users/frowing/Downloads/ScreenRecording_09-23-2026 21-26-31_1.MP4`.
- Existing game hub: `Views/Discover/GamesHubView.swift`.
- Existing arcade implementation: `Views/Discover/Games/SkylineDashView.swift`.
- Shared visual tokens: `Views/Shared/DesignSystem.swift`.
- Faus Switch assets: the supplied grunge texture (recolored into the palette as `FausSwitchTexture`) and a supplied robot reference image that the vector robot runner is modelled on.

## Product Principles

- Keep the primary interaction immediately understandable.
- Prefer a small, complete playable loop over several unfinished modes.
- Keep failure rules legible and fair; solid platforms are obstacles, not lethal surfaces, while falling behind the scrolling viewport is a clear loss condition.
- Use FausCrew's social context only where it improves the game rather than adding multiplayer complexity by default.
- Separate deterministic gameplay rules from presentation so balancing and testing remain inexpensive.

## Accessibility & Inclusion

- Gameplay controls should use the entire safe playfield as a touch target.
- Important hazard states must not rely on color alone.
- Haptics and visual feedback should complement one another.
- Reduce Motion should replace decorative parallax and large transitions without changing game timing.
