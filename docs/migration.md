# Installation and migration

Build and test in isolation first. Do not install while another agent is working
on the running app or its configuration. Reconcile that work before switching the
installed version.

1. Run `swift test` and `./scripts/lint.sh`.
2. Build with `./scripts/build_app.sh release`.
3. Run `./scripts/install.sh` to snapshot the existing command and configuration,
   install the command, import JSON settings and generate startup entry points.
4. Run `~/.local/bin/macarchy doctor`.
5. Apply the existing theme and verify the visible desktop before cycling themes.
6. Open `dist/Macarchy.app` after stopping the old app.

The installer leaves rollback files in a timestamped directory and prints its
path. It does not delete legacy settings or the previous app. Compatibility
outputs remain until their external readers are migrated. The visible app name
changes; the bundle identifier, executable and installed configuration directory
remain stable.
