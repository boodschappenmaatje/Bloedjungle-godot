# Native iPhone bunker asset test zone

This is an isolated Godot scene entered from the app's main menu. It loads the real baked GLB at `res://assets/tests/bunker/bloedjungle_bunker_hq.glb` as a `PackedScene`, so Godot's normal glTF importer creates the actual mobile `StandardMaterial3D` resources. It does not change the production level, the playable bunker, its colliders, gameplay scripts, or the global renderer settings.

## Existing GitHub updater

The app already uses the GitHub release tagged `updates`; it does not poll a Git branch. `.github/workflows/ota.yml` exports a resource patch from the commit in `ota/basis.txt`, adds a manifest containing the PCK size and SHA-256, and uploads both to that release. The app's `Updater` accepts only a newer manifest with the same installed-app `base`, checks PCK size and SHA-256 before staging, asks the player before download, and can roll back an unstable patch. Godot `load("res://assets/tests/bunker/bloedjungle_bunker_hq.glb")` loads the model through normal project resource import; the PCK therefore carries its model and importable resources together. No arbitrary URL loader or network server is added.

## iPhone steps

1. In the installed Bloedjungle app, open **Updates** from the main menu. If a read-only GitHub token is already stored, leave it in place. If required, use a fine-grained token scoped to this repository with Contents: Read-only; enter it only in the app's Updates screen.
2. Tap **Controleren**. When the tested `updates` release appears, tap **Download en installeer** and confirm.
3. Fully close Bloedjungle and open it again so the staged PCK loads. The updater verifies the manifest hash and app base and will roll back after repeated unstable starts.
4. From the main menu tap **3D Asset Test Zone · Bunker**. Use Schuin, Gameplay, or Voorzijde. Drag to orbit; pinch (or mouse wheel) to zoom. Terug naar hoofdmenu returns without opening a mission.
5. Allow at least 10 seconds for first-use shader compilation, tap **Reset meting**, then let the scene run while keeping the camera fixed. The panel reports current/recent-average/min/max FPS and Godot-reported process/video memory. Tap **Bewaar meting** to save a JSON snapshot under `user://bunker_asset_test_latest.json`.
6. For a useful device result, record the iPhone model, iOS version, viewport resolution, renderer, average/minimum FPS after warm-up, Godot process-memory peak, video-memory reading (or n/b), and whether any visible stutter or material mismatch occurred. Do not treat a headless CI run as a device performance test.

The existing updater release `updates` is the delivery channel, so publishing an OTA patch makes the accepted test build available to app installations that check that channel. No separate unverified runtime downloader is introduced. Test results do not imply physical iPhone validation until someone runs the scene in the installed app on the device.
