# TEAM command fixture

This small Godot project has no 3D assets. It symlinks the production `TeamCommands`, `TouchSticks`, `CombatButtons`, and command controller scripts, then supplies lightweight UI/Game stubs for input routing and wheel selection.

Run from the repository root:

```sh
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tests/run_team_commands_tests.sh
```

The tests cover the pure shared controller and soldier-goal logic, combined build/team entry and synthetic touch/mouse routing, radial sector and availability choices, and the real `Ally` script against lightweight model/game stubs. The fixture cannot replace a full 3D gameplay run or a physical Xogot touch test.
