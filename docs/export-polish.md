# macOS release packaging and QA

The production exporter copies only `assets`, `localization`, `resources`, `scenes`, and `scripts` into a fresh temporary workspace. It removes editor integration before import/export. The development project remains unchanged. Tests, documentation, addon source and old builds are absent from that workspace and the final PCK. The archive contains `Crownfront.app` plus the required Godot and project-asset license notices; its internal project name remains unchanged so existing preferences keep the same user-data path. The native game window title is Crownfront.

```sh
python3 tests/build_macos.py \
  --engine /Users/lova/Downloads/Godot.app/Contents/MacOS/Godot \
  --template /private/tmp/crownfront-macos-template.zip \
  --output builds/Crownfront.zip
```

Use an official Godot **4.6.2 stable** macOS template archive matching the editor. When templates are installed through Godot, omit `--template`. The local template used for this milestone was extracted from the official full template download after SHA-512 verification by the lead agent.

The preset targets universal Intel/Apple Silicon macOS, uses ad-hoc signing and does not notarize. Intel minimum version is 10.15 and Apple Silicon minimum is 11.0; these are configured deployment targets, not a claim of testing on those OS versions. The staged project enables the texture import format required by the universal exporter. No engine executable or template is checked into source control.

In an environment where process permission must be granted separately, use `--stage-only /private/tmp/new-directory` to prepare source, then run the configured Godot executable with `--headless --path /private/tmp/new-directory --import`, followed by `--headless --path /private/tmp/new-directory --export-release macOS /absolute/path/Crownfront.zip`. Finish with `python3 tests/build_macos.py --finalize-only --output /absolute/path/Crownfront.zip` to normalize the outer bundle name and write the archive checksum. Staging requires a new directory to prevent accidental inclusion of old files. Finalization changes only ZIP entry prefixes, preserving every signed file byte.

## Verification method

`tests/export_qa_prepare.py ARCHIVE NEW_DIRECTORY` inspects the Godot 4 PCK directory, rejects development resources, confirms both packaged translations and extracts the app as `Crownfront.app`. `manifest.json` records the PCK SHA-256, resource names and executable path. Extraction preserves executable permissions.

Passing `--instrument` creates an independent QA copy and an external `override.cfg` autoload. The diagnostic script stays outside the PCK, and an isolated application name selects a new user-data directory. The fixture aborts before writing if that isolation is absent. The production binary and PCK are unmodified; the external override is **not** distributed. The fixture checks real compiled production code and resources; it is automated instrumented verification rather than manual interaction with every UI control.

The actual release binary should be launched twice with user arguments `-- write /absolute/capture/directory`, then `-- read /absolute/capture/directory`. The first launch exercises initial English, settings controls, Russian, audio mix output, recruitment, routes, towers, upgrades, King outcomes and restart. The second tests startup persistence from the first process. Use `--language ru` for the first launch to challenge the explicit fresh-English rule. Launch a separate untouched app copy normally as well, with a bounded `--quit-after` for automated checking.

## Environment and limitations

The development Mac is Intel x86_64, macOS 26.5.2 (25F84), using official Godot 4.6.2 stable (`71f334935`). Apple Silicon, Windows, Linux, Gatekeeper quarantine/download behavior, notarization and App Store distribution are not tested here. Ad-hoc signing supports local verification; public distribution needs an appropriate signing/notarization workflow.

## Recorded package evidence

- Final source stage: `/private/tmp/crownfront-production-stage-3`. All production source/resource directories were compared byte-for-byte with the working tree after export; no differences.
- Archive: `builds/Crownfront.zip`, 62,808,963 bytes (59.90 MiB), SHA-256 `cef72127b12ee1d27b9e6a99a36784e4f9b0e017cacb01fe9829dcb18c6b124f`. `builds/Crownfront.sha256` contains this checksum. The archive includes `GODOT-LICENSES.txt` and `CROWNFRONT-ASSETS.txt` beside the application bundle. Executable inspection confirms both x86_64 and arm64 slices; only x86_64 was run.
- Production PCK: 104 resources, 174,544 bytes, SHA-256 `168128dcaccd6e2bf0fbb1dd33aae93375a13e4b6d4db6846eaaa66678ecdcfe`.
- Untouched and externally instrumented copies have identical production PCK hashes. Both translations are present; no test, documentation, MCP or editor-addon resource paths occur in the PCK.
- Clean extraction of the finalized ZIP to `/private/tmp/crownfront-final-signature-check/Crownfront.app` passes `codesign --verify --deep --strict`. All seven signed application files were compared byte-for-byte before/after the ZIP bundle-name normalization; all match. macOS FileProvider added Finder metadata to an extraction under the synced Documents workspace, which caused strict verification to reject that extraction; the same archive extracted outside FileProvider verifies cleanly. The ZIP itself is unaffected.
- Real preference file checksum was recorded before QA and verified unchanged afterwards. QA uses its own application-name directory and never overwrites the developer's preference file.
- An initial headless run of the **actual release binary** proved the external autoload method and passed 21 of 22 checks. The only failure was writing the isolated user-data directory under the filesystem sandbox; this was an execution-permission limitation. The subsequent authorized native GUI run passed **22/22**, including that save, with no engine/resource errors. A second separate native process passed **8/8**, restoring Russian, Master 37%, SFX 64%, disabled guidance and windowed display. Total: **30 native release assertions, zero failures**.
- Native rendering used macOS OpenGL 4.1 Compatibility on AMD Radeon Pro 5300M. The real native audio mixer emitted a peak of 0.101283, above silence and below clipping. This verifies signal output through the mixer; the musical character/mix still benefits from subjective human listening.
- A separate untouched app copy, with no override or diagnostic autoload, launched outside the editor and exited normally with a clean runtime log. Instrumentation was used only in the independent QA copy.
- Five real release viewport captures at 1280×720 were inspected: initial English onboarding/HUD, Russian settings, victory, defeat and Russian after a process restart. Text and controls are readable without clipping. Source-runtime resolution/language matrices are covered by the lead's broader verification report, not conflated with these native release captures.

The initial headless log is `tests/artifacts/export-native-headless.log`. Successful native logs are `export-native-gui-write.log`, `export-native-gui-read.log`, and `export-native-production.log` under `tests/artifacts`. Captures use the `native-*.png` prefix there. Clean export logs are `builds/export-import.log` and `builds/export-release.log`; full PCK inventories are in `builds/native-production/manifest.json` and `builds/native-qa/manifest.json`.
