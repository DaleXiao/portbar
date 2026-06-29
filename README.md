# PortBar

PortBar is a macOS menu bar app for seeing which local ports are currently used by apps and processes.

It scans local sockets with the system `lsof` command and shows TCP listening ports plus bound UDP ports in a compact popover.

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
