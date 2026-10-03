# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

HouseFlow is used by members of a shared household. Repository evidence shows that members manage a home, chores, profiles, and lightweight games in the same app. The exact audience demographics remain open.

## Product Purpose

HouseFlow brings recurring household coordination and small social moments into one native app. Success means household members can understand their responsibilities quickly and return for lightweight shared interactions without leaving the household context.

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
- House-Switch remains an existing, separate game surface.
- House-Switch gameplay is landscape-only. Its lobby explains the requirement before starting and the run begins only after the scene enters a landscape layout.
- Leaving House-Tanks or House-Switch returns the Games screen to portrait orientation.
- The course scrolls forward continuously. Hitting a solid obstacle does not pause that movement; a runner that fully leaves the left edge is eliminated.
- The finite course is twice its original length and contains alternating floor and ceiling gaps. Falling through a gap carries the runner off-screen and ends the run.
- Small one-use speed pads provide a brief forward gain relative to the camera, helping the runner recover some screen space after obstacles.
- A tap reverses gravity only while the runner's base is supported by solid geometry. Mid-air taps are ignored.
- Platforms are solid geometry. Contact with a platform's front or side does **not** kill the player.
- Explicit hazards such as active lasers may end a run.
- The first implementation is a solo, finite, playable course; Endless and multiplayer remain open follow-up decisions.
- House-Switch must not copy the reference game's name, artwork, or proprietary assets.
- Project changes must not be committed without a commit message supplied by the user.

## Brand Commitments

- Preserve the HouseFlow name and the app's existing friendly, rounded, colorful native character.
- The game is named **House-Switch**.
- Gameplay may be more immersive and energetic than utility screens, while navigation and controls remain recognizably native to the app.

## Evidence on Hand

- Reference recording: `/Users/frowing/Documents/SS/Ekran Kaydı 2026-09-20 23.04.40.mov`.
- House-Tanks reference recording: `/Users/frowing/Downloads/ScreenRecording_09-23-2026 21-26-31_1.MP4`.
- Existing game hub: `Views/Discover/GamesHubView.swift`.
- Existing arcade implementation: `Views/Discover/Games/SkylineDashView.swift`.
- Shared visual tokens: `Views/Shared/DesignSystem.swift`.
- No approved House-Switch illustration or sprite assets are currently present; future work must not imply that such assets were supplied.

## Product Principles

- Keep the primary interaction immediately understandable.
- Prefer a small, complete playable loop over several unfinished modes.
- Keep failure rules legible and fair; solid platforms are obstacles, not lethal surfaces, while falling behind the scrolling viewport is a clear loss condition.
- Use HouseFlow's social context only where it improves the game rather than adding multiplayer complexity by default.
- Separate deterministic gameplay rules from presentation so balancing and testing remain inexpensive.

## Accessibility & Inclusion

- Gameplay controls should use the entire safe playfield as a touch target.
- Important hazard states must not rely on color alone.
- Haptics and visual feedback should complement one another.
- Reduce Motion should replace decorative parallax and large transitions without changing game timing.
