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
- The confirmed new game name is **House-Switch**.
- House-Switch gameplay is landscape-only. Its lobby explains the requirement before starting and the run begins only after the scene enters a landscape layout.
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
