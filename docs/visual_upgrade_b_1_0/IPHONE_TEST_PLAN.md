# Visual Upgrade B — iPhone acceptance run

The PR produces an **unsigned** iOS IPA. GitHub Actions validates the iOS export; it does not install or run the game on an iPhone. The tester must sign the IPA with their own Apple developer account (for example through AltStore/AltServer or Xcode). Do not install this build over a production copy unless that is intentional.

## Build to install

Use the `bloedjungle-ios-unsigned-<commit>` artifact from the latest successful **iOS unsigned IPA** run on PR #237. Download the artifact ZIP, extract `Bloedjungle.ipa`, and sign/install it on the test iPhone. Check the commit SHA shown on the Actions run against the PR head before installing.

The separate `visual-upgrade-b-godot-<commit>` artifact contains genuine Godot screenshots, the renderer/backend diagnostics and Linux software timing data. It is comparison evidence; it is not a device build or an iPhone performance result.

## Keep the comparison controlled

- Record iPhone model, iOS version, battery/thermal state, game quality setting, render scale, and whether Low Power Mode is on.
- Use the normal gameplay camera and existing HUD/controls. Start on a clear day with the same quality setting used for the existing screenshot.
- Test at the usual render scale first. The 100% render-scale capture is a detail diagnostic, not the acceptance preset.
- Let the scene run for 30 seconds before recording each segment so shader and asset warm-up do not dominate the result.

## Run and record

1. **Still scene:** stand beside the jungle trail for 60 seconds. Record a 20-second screen capture and the FPS overlay at the start/end. Look for stable foliage, readable soil/gravel, plant contact at the ground, and clear sightlines.
2. **Movement and shimmer:** walk and jog along the trail and through its shoulder vegetation for 60 seconds. Look for foliage/ground shimmer, visible LOD transitions, plants popping, and any blockage of soldiers or firing lanes.
3. **Large fight:** repeat the heaviest normal encounter available for at least 2 minutes, including weapon fire and movement. Record the lowest sustained FPS you observe, pauses, heat, and whether the camera/HUD stay responsive.
4. **Buildings and river:** check the road/building edges and river bank while moving past them. Confirm that building placement, collisions, controls and combat remain unchanged.

The in-game FPS label is instantaneous; it cannot establish a 1% low. For frame-time and 1% low acceptance, record a Metal System Trace with Xcode Instruments on the connected iPhone. If Instruments is unavailable, report that result as **not measured** rather than estimating it from the overlay.

## Acceptance notes

Attach the screen recording and fill in:

- iPhone model / iOS:
- Quality / render scale:
- Still-scene FPS range:
- Movement shimmer or LOD issues:
- Large-fight lowest sustained FPS / hitches:
- 1% low and frame-time result (Instruments, or `not measured`):
- Device temperature/thermal throttling:
- Gameplay, collision, HUD or sightline regressions:

The upgrade remains visually and mobile-pending until this device run is reviewed. No iPhone test is claimed by the Linux/Vulkan or Linux/OpenGL software captures.
