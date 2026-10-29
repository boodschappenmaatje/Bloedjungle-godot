# Godot GLB import metadata

Godot's `*.glb.import` files are source-controlled import settings and resource
remaps. The generated scene and texture cache under `.godot/` is machine-local
and must stay out of Git. `.gitignore` therefore keeps ignoring import files in
general while allowing `assets/**/*.glb.import`.

Generate or update these files through the Godot 4.7.2 editor importer. Do not
copy `.godot/imported` cache files into the repository. Existing sidecars may
contain asset-specific import scripts or settings; preserve those when changing
an asset.

Run the metadata check before submitting asset changes:

```sh
python3 tools/check_glb_import_metadata.py
```

The check verifies each GLB under `assets/` has a parseable Godot scene import
configuration, matching `source_file` and remap destinations, and any configured
import script exists. GitHub Actions runs it when GLB assets, import metadata, or
the check itself changes.

The one-time repair and clean-checkout verification evidence is in
`artifacts/godot_import_metadata/`, including the per-file GLB hashes, editor
progress/error log, resource samples, and process timing.
