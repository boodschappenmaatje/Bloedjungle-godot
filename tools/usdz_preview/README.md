# iPhone USDZ-preview

For every Bloedjungle asset, keep the editable `.blend` source and Godot-ready `.glb`, and create a separate `.usdz` preview for iPhone Files / Quick Look. USDZ is a review copy and does not replace either production asset.

## Export from Blender

Blender 4.5's native USD exporter can write a `.usdz` package directly. The helper imports a `.glb` or opens a `.blend` in memory, exports visible objects, converts the stage to meters, writes USD Preview Surface materials and their texture dependencies, and caps preview textures at 2048 px by default. It does not save or alter the source file. Existing outputs are protected from accidental overwrite unless `--overwrite` is explicitly passed.

On the iMac, prefer the High Quality Showcase `.blend` when its textures are available. Use the game `.glb` when it is the complete, portable source or when preserving its imported animation tracks is the priority.

```sh
BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
SOURCE='assets/bunker/high_quality/Bloedjungle_Bunker_HQ_Source.blend'
USDZ="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Bloedjungle Previews/bunker_v1/Bloedjungle_Bunker_HQ_iPhone.usdz"
REPORT="$HOME/Documents/Bloedjungle 3D — Performance/pipeline-v1/reports/bunker_v1/iphone_usdz.json"

"$BLENDER" --background --factory-startup \
  --python tools/usdz_preview/export_usdz.py -- \
  --source "$SOURCE" --output "$USDZ" --report "$REPORT"
"$BLENDER" --background --factory-startup --python tools/usdz_preview/validate_usdz.py -- \
  --usdz "$USDZ" --report "${USDZ%.usdz}_validation.json" \
  --export-receipt "$REPORT"
```

For a GLB, set `SOURCE` to its `.glb` path. If an agreed animation is required, add `--require-animation`; the exporter only samples animation that is active on the imported scene/NLA timeline. Set the Blender scene's frame range to the approved clip range before exporting. Independent actions that are not on that timeline are not silently claimed as exported clips. Validate playback in Quick Look; `usdchecker` validates structure, not animation playback.

Choose a new asset/version directory and filename for each preview. The helper refuses to overwrite an existing USDZ or report unless `--overwrite` is supplied. Keep the `.blend`, `.glb`, and any existing previews untouched.

## iPhone delivery

When the local iCloud Drive container is available, save to:

```text
~/Library/Mobile Documents/com~apple~CloudDocs/Bloedjungle Previews/<asset>/<version>/<asset>_iPhone.usdz
```

Otherwise save under `previews/usdz/<asset>/<version>/` in the project and provide a direct file download link. After iCloud finishes syncing, the user can open **Files → iCloud Drive → Bloedjungle Previews**, tap the `.usdz`, and inspect/rotate it in Quick Look without a website or third-party viewer.

`validate_usdz.py` runs Apple's `usdchecker --arkit`, lists package contents with `usdzip`, verifies the archive and hashes, and can extend the Blender export receipt. A successful check on macOS does not constitute an iPhone-device test. Report whether the Mac Quick Look preview and any actual iPhone animation playback were checked.

References: [Blender 4.5 USD export](https://docs.blender.org/manual/en/4.5/files/import_export/usd.html), [Apple USD authoring](https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices), [Apple Quick Look](https://developer.apple.com/documentation/quicklook).
