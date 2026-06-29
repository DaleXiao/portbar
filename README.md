# PortBar

PortBar is a macOS menu bar app for seeing which local ports are currently used by apps and processes.

It scans local sockets with the system `lsof` command and shows TCP listening ports plus bound UDP ports in a compact popover.
<img width="403" height="367" alt="iShot_2026-06-29_19 32 26" src="https://github.com/user-attachments/assets/c4a7198d-bf79-4868-a952-c39d5d3b3299" />

## Build

Requirements:

- macOS 14 or newer
- Swift 5.9 or newer

Build from source:

```sh
swift build
```

Build, bundle, and launch from `dist/PortBar.app`:

```sh
./script/build_and_run.sh --verify
```

## Icon

The first version uses a system menu bar symbol. When the final icon is ready, place it at:

```text
Resources/AppIcon.icns
```
