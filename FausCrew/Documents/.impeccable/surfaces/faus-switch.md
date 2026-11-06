# Faus Switch Surface Direction

## Mode

Experience

## Product Mechanism

A robot runner crosses a landscape, continuously scrolling course with other robots: local bots in demo, housemates online. A supported tap reverses gravity; mid-air taps are ignored. Solid impacts are non-lethal, but a blocked robot can fall behind the viewport. Obstacles come in groups of two or three that split the screen into passages. After the horizontal run the course bends upward and climbs (the screen stays landscape); robots then switch between the left and right walls. After the climb it bends left again and runs to the left, upside down, to a finish line on the left. Robots are solid to each other (stacked, sole to sole, nose to tail) and each starts on its own color-coded platform at the same start line.

## Inherited World

Faus Switch extends FausCrew's rounded native interface with its own light palette (#D8FDD4, #3D896D, #30021F, #164F52, #B6A0CF, #D5E8A0, #E6D5B7, plus berry #7A2453 for danger). The background is the supplied texture recolored light; robots, rails and blocks are dark.

## First Viewport

Portrait lobby: robot mark and title, then Demo and Online mode cards. Demo setup asks for a robot color and the bot count; the online room shows status, color, roster and Ready.

## Visitor Path

Games hub → mode → setup or room → landscape race (countdown, race) → pause (demo) / result → race again, rematch, change setup or back.

## Signature Interaction

While the robot's feet touch a surface, a tap mirrors it to the opposite rail. The race ranks robots by finish time, then distance; standings appear only in the result panel. During the countdown each robot shows its player's name beside it.

## Motion Grammar

- One 140 ms vertical mirror per accepted flip; instant under Reduce Motion.
- Camera advances at the course speed regardless of collisions.
- Background texture parallax at 28% of camera speed; static under Reduce Motion.
- Portals read from their ring shape and pulse, slow pads from their backward chevrons, not color alone.

## States

- Lobby (mode, demo setup, online room)
- Countdown
- Racing (local robot running, finished, or crashed and spectating)
- Paused (demo only)
- Result (demo standings; online persisted result with rematch)
- Online notices: syncing, reconnecting, recovering, control transferred, connection failed

## Quality Bar

- Full-playfield touch interaction; HUD never blocks taps.
- No progress bar and no flip counter.
- Minimum 44 pt controls and Dynamic Type on SwiftUI copy.
- Mid-air taps never change gravity, online or demo.
- Physics match the original constants; the server runs the same simulation.
- Localization works without a network response.

## Verification Constraint

Build and run the project's tests only; do not drive simulators without asking.
