# TEAM command fixture

This small Godot project has no 3D assets. It symlinks the production `TeamCommands`, `TouchSticks`, and command controller scripts, then supplies only UI/Game stubs for parsing and input routing.

Run from the repository root:

```sh
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tests/run_team_commands_tests.sh
```

The first test covers the pure shared controller and soldier-goal logic; the second loads the actual HUD/touch adapters and feeds synthetic touch and mouse events through the production routing path. The third loads the real `Ally` script against lightweight model/game stubs and checks that a barracks recruit initializes and gets its follow goal. The fixture cannot replace a full 3D gameplay run or a physical Xogot touch test.
