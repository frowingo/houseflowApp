# House-Switch Surface Direction

## Mode

Experience

## Product Mechanism

A house-shaped runner crosses a landscape-only, continuously scrolling course. A supported tap reverses gravity; mid-air taps are ignored. Solid impacts remain non-lethal, but a blocked runner can fall behind the viewport.

## Inherited World

House-Switch extends HouseFlow's rounded, friendly native interface. The gameplay layer deepens the existing cool blue/teal palette and reserves warm orange for danger and finish feedback. Navigation, type, controls, localization, and accessibility remain native iOS rather than imitating the reference game's web chrome.

## First Viewport

The lobby leads with a prominent landscape-required notice, then teaches supported gravity flips, the moving-course rule, and laser danger. Starting rotates and locks the game to landscape before the run begins.

## Visitor Path

Games hub → briefing → active course → pause or run result → restart or return to games.

## Signature Interaction

While the house base touches a solid surface, a playfield tap reverses gravity, rotates the runner, and sends it toward the opposite rail. Airborne taps produce no flip. A side impact blocks the runner while the camera continues. Mint arrow pads briefly move the runner right relative to the camera; orange-edged gaps in either rail send an unsupported runner off-screen.

## Motion Grammar

- One authored gravity-flip rotation and pulse.
- Camera advances continuously at the course speed, independently of obstacle collisions.
- Background movement is tied to progress and becomes static under Reduce Motion.
- Laser warning, activation, and cooldown use brightness and opacity, not color alone.
- Speed pads retain visible right-pointing arrows; rail gaps remain physical openings with warm edge markers.

## States

- Briefing
- Playing
- Paused
- Crashed by an explicit hazard, vertical boundary, or falling fully behind the left edge
- Finished

## Quality Bar

- Full-playfield touch interaction without obscuring pause controls.
- Minimum 44 pt controls and Dynamic Type on non-gameplay text.
- Solid platform contacts never invoke the crash path directly; only leaving the viewport after being blocked does.
- Active gameplay never starts in portrait and remains locked to landscape until the game closes.
- Mid-air taps never change gravity.
- The extended course keeps both rails legible around physical gaps, and speed pads provide only a small local recovery gain.
- Course geometry scales within landscape iPhone and iPad playfields.
- Localization remains useful without a network response.
- No reference-game name, artwork, or proprietary asset is copied.

## Verification Constraint

The project owner requires explicit permission before any build. Until granted, verification is limited to static parsing, diff checks, and code review; simulator screenshots are intentionally absent.
