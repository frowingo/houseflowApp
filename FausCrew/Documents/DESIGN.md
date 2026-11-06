---
name: "FausCrew — Faus Switch Surface"
description: "A light, textured gravity race for Faus Switch inside FausCrew: dark robots and machined blocks on a pale mint course."
colors:
  course-mint: "#D8FDD4"
  signal-green: "#3D896D"
  deep-plum: "#30021F"
  machine-teal: "#164F52"
  laser-lavender: "#B6A0CF"
  pad-lime: "#D5E8A0"
  paper-sand: "#E6D5B7"
  hazard-berry: "#7A2453"
  wine: "#692747"
  deep-wine: "#501536"
  light-sand: "#F3EBDD"
  visor-ink: "#0E2A2C"
  panel: "linear-gradient(135deg, #F3EBDD, #E6D5B7)"
  secondary-ink: "rgba(22, 79, 82, 0.82)"
typography:
  display:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "34px"
    fontWeight: 900
  title:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "22px"
    fontWeight: 900
  headline:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "17px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "17px"
    fontWeight: 400
  supporting:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "15px"
    fontWeight: 400
  label:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "12px"
    fontWeight: 800
rounded:
  block: "5px"
  control: "12px"
  action: "12px"
  panel: "16px"
  overlay: "20px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
components:
  action-primary:
    backgroundColor: "{colors.wine}"
    textColor: "{colors.light-sand}"
    typography: "{typography.headline}"
    rounded: "{rounded.action}"
    height: "56px"
    padding: "0 20px"
  action-not-ready:
    backgroundColor: "{colors.deep-plum}"
    textColor: "{colors.course-mint}"
    typography: "{typography.headline}"
    rounded: "{rounded.action}"
    height: "56px"
  section-card:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.deep-plum}"
    rounded: "{rounded.panel}"
    padding: "16px"
  state-overlay:
    backgroundColor: "{colors.course-mint}"
    textColor: "{colors.deep-plum}"
    rounded: "{rounded.overlay}"
    padding: "20px"
  hud-control:
    backgroundColor: "{colors.machine-teal}"
    textColor: "{colors.course-mint}"
    rounded: "{rounded.control}"
  standing-chip:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.deep-plum}"
    rounded: "{rounded.pill}"
---

# Design System: FausCrew — Faus Switch Surface

## Overview

**Creative North Star: "Robots on a Mint Sheet"**

Faus Switch is a landscape gravity race inside FausCrew. Up to four robots (demo: you and one to three bots; online: everyone in the house) run on the same scrolling course; a tap on a surface flips gravity between floor and ceiling. The course sits on a pale, grainy mint texture; everything that matters for play — robots, rails, blocks, gap stripes — is dark so it reads instantly against it. Navigation, type and controls stay native iOS.

This document is bounded to the Faus Switch surface. It is not authority to restyle other FausCrew screens.

**Key Characteristics:**

- One light background (the supplied grunge texture, duotoned into the palette) and dark play objects.
- A robot runner modelled on the supplied reference: wide rounded head, dark visor with two white rounded-square eyes, a side ear pad, a small body with arms and legs. Each player picks one of eight body colors.
- Obstacles arrive in groups of two or three that split the play band into openings; no single column fully blocks the screen from only the top or only the bottom.
- A minimal HUD: pause (demo) or leave (online), the music button and the sound button. There are no live standings, no progress bar and no flip counter; during the countdown each robot's player name sits beside it, and the result panel shows who was which robot and the order.
- Portrait lobby, landscape race.

## Colors

The palette is #D8FDD4, #3D896D, #30021F, #164F52, #B6A0CF, #D5E8A0 and #E6D5B7, with two wines, **Wine** (#692747) and **Deep Wine** (#501536), so green never dominates. Two extra tones are allowed because play needs them: **Hazard Berry** (#7A2453) for crash results and warnings, and **Visor Ink** (#0E2A2C), a darker teal for the robot visor. **Light Sand** (#F3EBDD) is Paper Sand mixed halfway to white.

- **Course Mint (#D8FDD4):** the light end of the background texture and the finish line.
- **Paper Sand (#E6D5B7) → Light Sand:** every card and panel (lobby cards, mode bar, pause and result panels, the Games card) is a diagonal gradient from Light Sand at the top left to Paper Sand; result rows are Light Sand; text on dark fills is Light Sand.
- **Wine (#692747):** primary actions, section titles, kicker, links and chevrons, the online mode icon, every third rail section (the leftward run) and one of the block colors.
- **Deep Wine (#501536):** secondary ink, HUD buttons, selected-tile outline, the climb's rails, speed-pad outlines and one of the block colors.
- **Machine Teal (#164F52):** the first run's rails and one of the block colors.
- **Signal Green (#3D896D):** the first run's running-surface line, speed pads and positive states.
- **Deep Plum (#30021F):** primary ink, gap chevrons and stripes, the finish checks and the countdown disc.
- **Laser Lavender (#B6A0CF):** portal swirls and exit rings, slow pads, the local robot's halo, the demo mode icon, selected color tiles, the local name tag and result row, the climb's running-surface line and one of the block colors.
- **Pad Lime (#D5E8A0):** the chest light, the "you" marker, the leftward run's running-surface line and start-platform lines.

Robot body colors, one per hue so they tell apart (all dark enough to read on the mint course): Plum #30021F, Forest #3D896D, Ocean #3F6C9E, Lavender #8467B8, Olive #7D8B2E, Bronze #B06A3B, Graphite #5B5560, Berry #B0446F. Berry is lighter than the wine blocks so a berry robot never blends into them. The default color is Lavender. Limbs and outlines are the body color darkened; the visor is Visor Ink and the eyes are near-white.

### Named Rules

**Light Field, Dark Pieces.** The background is always the lightest thing on screen. Anything a player must react to is darker than the texture behind it.

**Berry Means Danger.** Only crash results, the left-behind line and destructive actions use Hazard Berry.

## Typography

Native SF Pro semantic styles throughout; weight carries the arcade tone. Section titles are uppercase caption-heavy in Signal Green. Countdown digits are rounded black, monospaced.

**The Native Scale Rule.** Interface copy stays in SwiftUI so localization and Dynamic Type work; nothing but the course geometry is drawn in SpriteKit.

## Layout

**Lobby (portrait):** header (robot mark, kicker, title, subtitle) → mode cards (Demo, Online) → after choosing: mode bar with "change mode" → demo setup (robot color grid of eight robot tiles, bot count 1–3 segmented, roster preview, best time) or online room (status with server countdown badge, the same color grid with the first-claim note, roster with ready states) → rules card. The rules card is a two-column grid of seven tiles, each a tiny looping 16:9 clip (2.2–3.6 s, drawn live on the mint course with teal rails and the player's chosen robot color) with a two- to four-word caption under it: tap on a surface, dodge the blocks, robots are solid, don't fall in gaps, green pads speed you up, purple pads slow you down, portals throw you back. Under Reduce Motion each clip holds one telling frame; VoiceOver reads the caption and the full rule sentence. A pinned bottom bar holds "Start" (demo, rotates to landscape) or "Ready / Not ready" plus the host's cancel (online).

**Race (landscape):** the SpriteKit course fills the screen. The world is 844 × 390 logical units scaled to the screen height; wider screens show more course ahead. Top-left: a 44-point deep wine button (pause in demo, leave in online); top-right: the music button (background track only) and next to it the sound button (effects only: flips and portals). Both choices are remembered separately. During the three-second start every robot has a name tag to its right (caption, heavy, a capsule in the robot's body color with mint text; the local player's tag is lavender with plum ink and reads "You"), and a large plum countdown disc sits at the right edge so the start line stays visible. The tags disappear when the run starts. A short tap hint appears at the bottom for the first seconds.

**Panels:** pause and results dim the race with plum at 38% and centre a sand gradient card (max 660 points wide) laid out for landscape: the header (44-point icon tile, title 3 black) and the standings table on the left, every action stacked in a 210-point column on the right (a 48-point primary button, 44-point text buttons). Standings use one column for up to four robots and two columns for more, with 32-point rows, so every panel fits the landscape screen without scrolling. Only very large text sizes that cannot fit fall back to a scrolling card.

## Course

The course first runs to the right, then bends upward in a quarter turn and climbs. The screen stays in landscape; the course itself turns. While climbing, the floor rail is the right wall and the ceiling rail the left wall, so robots switch left and right. After the climb a second left turn brings the course back to horizontal, now running to the left; the band is upside down there, so the floor rail is the top one and robots run toward the left edge, where the finish line is. Bends have no obstacles. Bends are fair: a robot keeps the share of the margin it was using, so no one is lost just because the view turns, and every robot still in the race stays on screen. Through each bend the camera fits the band from the left-behind line onward and zooms out a little (to about 70 %); there the line crosses the screen diagonally and the band behind it is dimmed plum with a berry line; on the climb it is centered on the shaft, zoomed to 75 %, with the robots in the lower part of the screen so more of the climb shows ahead; on the leftward run the robots sit 380 from the right edge at full size. The texture scrolls on both axes.

- **Rails:** solid bands along the floor and ceiling with a running-surface line and faint diagonal speed ticks, colored per section so each stretch reads apart: teal with green on the first run, Deep Wine with lavender on the climb, Wine with lime on the leftward run. A bend takes the colors of the section after it.
- **Blocks:** machined blocks (5-point corners, outline, recessed panel, two bolts) in four styles: teal/green, wine/lavender, lavender/deep wine, deep wine/sand. Every block of a group (blocks less than 200 apart) shares one style; groups take the styles in turn along the course, so neighboring groups differ, and a group never takes its section's rail color. They come in staggered pairs and triples — top+middle, bottom+middle, top+middle+bottom with two openings, diagonal stairs — so every group leaves at least one opening that a timed flip can reach.
- **Gaps:** real breaks in a rail, filled with plum hazard stripes and marked by plum chevrons on both lips.
- **Speed pads:** green strips (48 × 28) with three mint chevrons and a deep wine outline, floating in the band, never touching a rail. A robot gets the boost by passing through one, usually mid-flip.
- **Portals (replace the lasers):** an upright wine ring, 22 × 44, standing on the floor or hanging from the ceiling on a short wine foot, just taller than a robot; inside, a deep wine swirl with a lavender core pulses with the race clock (steady under Reduce Motion). Where it sends a robot is marked on the opposite rail, farther back (220 on the horizontal runs, 100 on the climb), with a faint lavender ring outlined in wine. Running into one moves the robot there, pulled toward that rail; the robot is never placed behind the left-behind line.
- **Slow pads:** lavender strips (48 × 28) with three deep wine chevrons pointing back against the run and a deep wine outline. Most lie flat on a rail — on landings after gaps and on rails a robot must leave before a block — and a few float in passages flips cross. Each robot is slowed by each pad once (100 slower for 0.8 s).
- **Finish:** a plum and mint checkered column.
- **Start platforms:** every robot starts on its own short slab (6 units thick, from 40 behind to 120 past the start line) at the same x. The slabs split the band into one lane per robot; floor-side robots stand on top, ceiling-side robots hang underneath. Each slab is filled with its robot's body color, outlined a shade darker, with a thin lime line on the face the robot stands on.

## The Robot

The robot is drawn at the size of its 27.2 × 33.6 physics box (80% of the old house runner). Robots are solid to each other: one can run on another's head, two with opposite gravity press sole to sole, and a faster robot is held behind a slower one. Feet on another robot count as a surface for flipping. It faces the run direction (right, then up, then left). A gravity flip mirrors it vertically over 140 ms (instant with Reduce Motion) so its feet stay on the new rail. Legs trot slightly while running. Boosts show two green speed streaks behind it. The local robot has a lavender halo and a lime "you" marker above the head. Crashed robots fade to 32% opacity; disconnected online robots are drawn at 55%.

## Motion and Feedback

- Sound: a soft looping chiptune track (F major, 116 BPM, 33 s) plays from the countdown to the end of the race, is quieter under result panels and notices, pauses with the game and stops when the race closes. The player's own accepted flip plays a short "bloop" that rises toward the ceiling and falls toward the floor, with a small random pitch spread. Bots and other players are silent. The music button mutes the track and the speaker button mutes the effects (flips and portals); each choice is remembered. The audio session is ambient, so the silent switch mutes it and other apps' audio keeps playing.

- Accepted flip: light haptic. Mid-air tap: rigid haptic at 55%, no state change.
- Portal: a short swirling "vwoop" (with the effects) and a warning haptic. Boost: medium haptic. Crash: error notification. Finish: success notification.
- The background texture scrolls at 28% of the camera speed and becomes static with Reduce Motion.
- Online corrections ease out within 80 ms; larger jumps snap.

## Do's and Don'ts

### Do:

- **Do** keep the whole playfield as the tap target; HUD pieces outside buttons never capture touches.
- **Do** keep obstacle groups split into passages and keep every play object darker than the texture.
- **Do** keep standings for the result panel only; during the race the course and robots carry the screen.
- **Do** start the race only in a landscape layout and return to portrait when it closes.
- **Do** keep 44-point minimum controls, semantic labels and Dynamic Type on all SwiftUI copy.

### Don't:

- **Don't** add a Start–Finish progress bar or a flip counter.
- **Don't** use a dark night background or neon glow on panels.
- **Don't** use Hazard Berry for anything but danger.
- **Don't** let a mid-air tap flip gravity.
- **Don't** copy the reference game's name, artwork or assets.
