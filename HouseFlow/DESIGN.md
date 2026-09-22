---
name: "HouseFlow — House-Switch Surface"
description: "A focused, neon-night arcade world for House-Switch inside HouseFlow."
colors:
  night-sky: "#071827"
  horizon-teal: "#123D4B"
  panel-ink: "rgba(10, 28, 45, 0.92)"
  action-mint: "#31D7C5"
  action-ink: "#041B22"
  hazard-orange: "#F28A3A"
  primary-ink: "rgba(255, 255, 255, 0.96)"
  secondary-ink: "rgba(255, 255, 255, 0.72)"
  quiet-track: "rgba(255, 255, 255, 0.16)"
typography:
  display:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "34px"
    fontWeight: 900
  title:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "28px"
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
    fontSize: "11px"
    fontWeight: 700
rounded:
  small-detail: "3px"
  platform: "8px"
  control: "12px"
  action: "16px"
  panel: "20px"
  overlay: "24px"
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
    backgroundColor: "{colors.action-mint}"
    textColor: "{colors.action-ink}"
    typography: "{typography.headline}"
    rounded: "{rounded.action}"
    height: "56px"
    padding: "0 20px"
  action-danger-result:
    backgroundColor: "{colors.hazard-orange}"
    textColor: "{colors.action-ink}"
    typography: "{typography.headline}"
    rounded: "{rounded.action}"
    height: "56px"
    padding: "0 20px"
  briefing-panel:
    backgroundColor: "{colors.panel-ink}"
    textColor: "{colors.primary-ink}"
    rounded: "{rounded.panel}"
    padding: "20px"
  landscape-notice:
    backgroundColor: "{colors.panel-ink}"
    textColor: "{colors.primary-ink}"
    rounded: "{rounded.panel}"
    padding: "16px"
  state-overlay:
    backgroundColor: "{colors.panel-ink}"
    textColor: "{colors.primary-ink}"
    rounded: "{rounded.overlay}"
    padding: "24px"
  hud-control:
    backgroundColor: "{colors.panel-ink}"
    textColor: "{colors.primary-ink}"
    rounded: "{rounded.control}"
---

# Design System: HouseFlow — House-Switch Surface

## Overview

**Creative North Star: "The Neon Household Run"**

House-Switch is a compact, landscape-only arcade world nested inside HouseFlow: a deep, cool nightscape where a small house becomes the runner. It feels energetic without abandoning the app's friendly native character. The lobby clearly establishes the required orientation before play, then the playfield owns the screen for the full run; surrounding interface stays concise, rounded, legible, and unmistakably iOS.

This document is intentionally bounded to the House-Switch game surface and the reusable visual or interaction vocabulary expressed by that surface. It is not authority to restyle unrelated HouseFlow screens. Within this boundary, mint communicates action, progress, and successful completion; orange communicates explicit danger and high-salience result feedback; translucent navy panels keep controls readable without separating them from the course.

**Key Characteristics:**

- Deep blue-to-teal night atmosphere with restrained neon accents.
- Native iOS typography, controls, accessibility, and navigation behavior.
- A prominent landscape requirement that gates and then locks the playable layout.
- Friendly continuous corners and compact translucent HUD surfaces.
- A house-shaped runner and gravity reversal as the signature visual interaction.
- Motion that explains gameplay state and yields to Reduce Motion.

## Colors

The palette is a cool, dark field with one dominant mint voice and a tightly reserved warm warning voice.

### Primary

- **Action Mint:** The sole default action and progress accent, used for primary actions, flip feedback, progress fill, right-pointing speed pads, platform guidance, and the finish gate.

### Secondary

- **Horizon Teal:** The lower atmosphere of the vertical sky gradient; it keeps the course cool and dimensional without competing with gameplay geometry.

### Tertiary

- **Hazard Orange:** Reserved for lasers, warm gap-edge markers, danger messaging, the runner's small door detail, best-time emphasis, and crash-result actions.

### Neutral

- **Night Sky:** The darkest backdrop anchor and upper end of the playfield gradient.
- **Panel Ink:** A high-opacity navy surface for briefing groups, HUD tiles, pause controls, and result overlays.
- **Primary Ink:** Near-white for essential labels and high-priority content on dark surfaces.
- **Secondary Ink:** Soft white for explanations, metadata, and secondary actions.
- **Action Ink:** Deep blue-black text placed on mint or orange filled actions.
- **Quiet Track:** Low-contrast white used for inactive progress tracks and subtle structural highlights.

### Named Rules

**The Two-Signal Rule.** Mint means act, advance, or finish; orange means danger or exceptional result feedback. Do not introduce a third competing accent inside House-Switch.

**The Orange Is Earned Rule.** Warm color stays rare enough that an active laser or crash result remains immediately legible.

## Typography

**Display Font:** SF Pro through native iOS semantic styles

**Body Font:** SF Pro through native iOS semantic styles

**Character:** The hierarchy is native, direct, and highly legible. Weight creates arcade confidence while Dynamic Type, rather than fixed decorative type, preserves HouseFlow's platform-native voice.

### Hierarchy

- **Display** (black, large-title semantic style): House-Switch briefing title only.
- **Title** (black, title semantic style): Pause, crash, and finish overlay titles.
- **Headline** (semibold by default): Primary actions, rule titles, and compact values.
- **Body** (regular): Overlay explanations and secondary action labels.
- **Supporting** (regular, subheadline semantic style): Rule explanations and transient play hints; use semibold only when the hint must remain readable over motion.
- **Label** (bold, caption semantic styles): Progress endpoints and compact HUD metadata. Time and flip values use monospaced digits for stable measurement.

### Named Rules

**The Native Scale Rule.** Keep non-gameplay copy on iOS semantic text styles so localization and Dynamic Type remain useful; do not freeze interface copy into SpriteKit labels.

## Layout

House-Switch uses a full-bleed playfield with safe, compact interface layers above it. The briefing is vertically scrollable, horizontally inset by the extra-large spacing step, and places a prominent landscape-required panel before the rules. Its persistent full-width action either starts immediately from an already-landscape layout or requests rotation and waits; the playable phase begins only after the measured viewport is wider than it is tall. Landscape remains the only supported run layout until the game view exits, when the app's default orientation policy returns.

During play, the top HUD uses a three-part row: a square pause control, a flexible progress meter, and a compact flip counter. A transient tap hint floats near the bottom and never captures touches. The finite course runs 8,840 points, twice its original length, with four alternating floor and ceiling gaps and five one-use speed pads. The camera advances from course progress independently of the player's physical position. A solid front or side impact may hold the house back while the course continues; failure occurs only when the entire runner has passed behind the left viewport edge, not when it is merely clipped. A fall through a rail gap continues off-screen before the run ends.

State overlays dim the entire playfield and center a scrollable panel with a maximum width of 430 points. Content uses the 24-point rhythm for major groups and 8-point rhythm for tightly related labels. Platforms, laser reach, finish geometry, gravity strength, and gravity-switch velocity resolve from the current playfield height so the same vertical traversal remains reachable across landscape iPhone and iPad layouts.

**The Course-First Rule.** Once play begins, remove briefing density and give nearly the entire viewport to the course; HUD elements exist only to pause, orient, or report progress.

**The Landscape Gate Rule.** Explain landscape-only play before the start action, wait for a real landscape viewport before entering the playable phase, and keep that orientation locked until the game exits.

## Elevation & Depth

Depth is primarily tonal: the night gradient, low-opacity skyline, translucent panels, outlined platforms, and glowing course signals establish layers. One ambient shadow belongs to the House-Switch mark, while SpriteKit glow belongs to the runner, active laser, and finish gate. Ordinary HUD surfaces remain shadowless so they feel anchored to the playfield rather than floating above it.

### Shadow Vocabulary

- **Mark Ambient:** A soft black shadow with 28% opacity, 18-point blur, and 10-point downward offset; use only for the large briefing mark.
- **Gameplay Signal Glow:** Tight shape glow on the player, laser, and finish gate; it communicates state or collision relevance, not generic decoration.

### Named Rules

**The Signal-Only Glow Rule.** Glow identifies interactive or hazardous course objects. Panels, copy, and routine controls do not glow.

## Shapes

The interface uses continuous rounded rectangles: 12-point corners for compact HUD controls, 16-point corners for actions, 20-point corners for briefing groups, and 24-point corners for the primary mark and state overlay. Capsules are reserved for progress geometry and the temporary tap hint. Course platforms use a firmer 8-point radius, while their thin highlight and mint outline make solid geometry readable without making it look lethal. Gaps remain real breaks in those rails with short amber edge markers. Speed pads are small mint strips with right-pointing arrows; the arrows make their purpose legible without relying on color alone.

The player silhouette is a compact house with a peaked roof, outlined body, small rounded window, and orange door. This recognizable silhouette is the surface's signature and should remain readable at gameplay scale.

## Components

### Buttons

- **Shape:** Full-width filled actions use a friendly continuous 16-point corner and a 56-point minimum height; the compact pause control is 46 points square with a 12-point corner.
- **Primary:** Mint fill, deep action ink, native headline weight, and a system symbol paired with the label.
- **Pressed / Focus:** Pressing scales the control to 97% with a damped spring. Accessibility focus stays semantic and the entire action remains at least 44 points high.
- **Result Variant:** Successful restart uses mint; hazard recovery may use orange. The quiet exit action is text-only with secondary ink and a 44-point minimum height.

### Cards / Containers

- **Corner Style:** Briefing groups use 20-point continuous corners; centered state overlays use 24-point continuous corners.
- **Background:** High-opacity panel ink over the still-visible course.
- **Shadow Strategy:** Flat by default; only the briefing mark receives ambient elevation.
- **Internal Padding:** 20 points for briefing content and 24 points for state overlays.

### Navigation

The native navigation bar is visible only during the briefing. Active play hides it and exposes an in-world pause control. The run owns landscape orientation until the game view exits. Leaving the app while playing pauses the run; returning never silently advances gameplay.

### Landscape Requirement

A full-width panel appears between the title and gameplay rules. Its 48-point landscape-rotation symbol, REQUIRED capsule, headline, and direct explanation make orientation a prerequisite rather than a footnote. If the system cannot rotate automatically, the same panel turns its symbol and badge orange and tells the player to rotate the device before trying again.

### Rule Row

A 44-point tinted icon tile leads a left-aligned title and supporting explanation. The lobby teaches five rules before play: supported gravity flips in mint, non-lethal solid impacts and continuous scrolling in cyan, floor and ceiling gaps in orange, short mint speed pads, and active lasers in orange. Gap copy tells players to change rails before an opening; pad copy explains the small forward recovery relative to the camera.

### Gameplay HUD

HUD surfaces share panel ink and 12-point continuous corners. The progress component pairs compact start/finish labels with a thin capsule track and mint fill. Numeric values use monospaced digits to prevent visual jitter.

### House Runner and Course Signals

The runner is a mint house with a white edge, dark window, orange door, and a soft circular aura. A playfield tap flips gravity only when a narrow probe under the house's gravity-facing base finds solid support. An accepted flip rotates the house toward the opposite rail over 180 milliseconds, pulses the aura over 220 milliseconds, increments the counter, and gives light haptic feedback. An airborne tap leaves gravity, orientation, and count unchanged and answers with a distinct rigid blocked haptic. On contact from the supported rail, each mint arrow pad gives one brief extra burst of speed relative to the camera, then dims after use. A runner falling into a gap is carried beyond the vertical viewport before elimination. Lasers move through dim, warning, active, and cooldown states using opacity and brightness so danger never relies on hue alone.

## Do's and Don'ts

### Do:

- **Do** keep the entire unobscured playfield available as the gravity-flip target while preserving explicit pause controls.
- **Do** make the landscape-only requirement prominent in the lobby, start only after landscape layout is confirmed, and keep the run locked there until exit.
- **Do** keep camera and course progression advancing when a solid obstacle blocks the player, and trigger left-behind failure only after the whole runner clears the left viewport edge.
- **Do** accept gravity flips only from the gravity-facing supported base; use distinct blocked feedback for airborne taps without changing gameplay state.
- **Do** scale vertical geometry, gravity, and switch velocity from playfield height so phone and iPad landscape traversal stays reachable.
- **Do** use mint for the principal action/progress channel and orange only for hazards or exceptional result feedback.
- **Do** keep solid platforms visually substantial and non-lethal; their outline and highlight should distinguish them from lasers.
- **Do** show the four alternating rail gaps as physical openings with amber edge markers and let a fall finish off-screen before ending the run.
- **Do** show all five one-use speed pads as short mint strips with right-pointing arrows; their brief boost should recover only a little screen space.
- **Do** pair motion and haptics with persistent visual state, and replace decorative parallax or large transitions when Reduce Motion is enabled.
- **Do** preserve native localization, Dynamic Type, semantic accessibility labels, and 44-point minimum controls outside the SpriteKit course.

### Don't:

- **Don't** extend this dark arcade treatment to unrelated HouseFlow surfaces without a separate design decision.
- **Don't** style ordinary panels or labels with neon glow; glow belongs to course signals.
- **Don't** use orange as a general secondary accent or let it compete with active hazards.
- **Don't** begin a run while the measured layout is portrait or restore portrait support before the game view exits.
- **Don't** pause course scrolling because a solid obstacle blocks the player, or fail the run while any part of the runner is still inside the left viewport edge.
- **Don't** let an airborne tap reverse gravity, rotate the house, or increment the flip count.
- **Don't** make a platform front or side impact look like failure; only explicit hazards, leaving the vertical boundary, or falling fully behind the left viewport end a run.
- **Don't** depict a gap as a solid platform or let an already-used speed pad imply another available boost.
- **Don't** copy the reference game's name, artwork, assets, or browser-like chrome.
