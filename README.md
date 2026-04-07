# mydock

`mydock` is a compact AppKit utility for macOS Sequoia that keeps a vertical app switcher on the left side of the screen.

## Current feature set

- Shows pinned apps first
- Shows dynamic apps only when they currently have visible windows
- Hides apps from the dynamic section when they are hidden
- Excludes menu bar only apps
- Displays slot indices for the first 10 items: `1...9, 0`
- Uses circular index badges in the top-left corner of the icon
- Shows window dots capped at 4
- Supports global hotkeys:
  - `Option+1 ... Option+9, Option+0`
  - `Option+D`
- Activates a clicked app
- Cycles visible windows for a hotkey-selected app when that app has more than one eligible window
- Launches a pinned app if it is not running and the bundle can be resolved on disk
- Supports right-click context menus for pin/unpin
- Persists pinned apps and layout settings in `UserDefaults`
- Provides a native settings window for layout tuning

## Build

1. Open [mydock.xcodeproj](/Users/alex/mydock/mydock.xcodeproj) in Xcode 16.4 or later.
2. Build and run the `mydock` scheme.

CLI build:

```bash
xcodebuild -project mydock.xcodeproj -scheme mydock -configuration Debug build
```

## Hotkeys

- `Option+1 ... Option+9, Option+0`: activate the app in the corresponding slot
- `Option+D`: hide or show the dock panel

Hotkey behavior:

- Hotkeys only target the first 10 slots
- Empty slots do nothing
- If the slot points to a stopped pinned app, `mydock` launches it
- If the slot has one visible window, `mydock` activates the app as before
- If the slot has multiple visible windows, the first press in the current `Option` hold focuses the first window in that app's stored order
- Repeated presses of the same slot while `Option` is still held advance through that app's window order
- Switching to another slot while still holding `Option` resets the per-slot cycle back to the first window for the newly selected app

## Window Cycling

`mydock` tracks a runtime-only window order per application.

Rules:

- Dock visibility and dot counts still come from Core Graphics window snapshots
- Exact cycling order comes from Accessibility window enumeration for the running app
- Only non-minimized AX windows from regular, non-hidden apps participate in the cycle
- Order is determined by the first time an AX window is observed by `mydock` during the current runtime session
- New windows are appended to the end of the app's cycle
- Closed or no-longer-eligible windows are removed from the cycle
- The stored window order is stable, but the current cycle position is scoped to the current `Option` hold session
- Manual window changes by the user do not reorder windows
- Releasing `Option` resets repeated-slot cycling back to the first window for the next hotkey sequence

Practical meaning:

- The window order is stable within the current `mydock` runtime session
- If the application disappears and later comes back with a new runtime session, the cycle is rebuilt
- If `mydock` starts after several windows are already open, public APIs still do not expose their true historical creation order; in that case `mydock` seeds initial order by first AX observation order

## Pin / Unpin

- Right-click an app icon to open the context menu
- Dynamic apps show `Pin to mydock`
- Pinned apps show `Unpin from mydock`
- Pinning appends the app to the pinned section immediately after the last existing pinned app
- Unpinning removes it from the pinned section; if the app has no eligible visible windows it disappears from the dock

Pinned apps are persisted in `UserDefaults`. Initial defaults still come from [`AppConfiguration.swift`](/Users/alex/mydock/mydock/Models/AppConfiguration.swift):

- `com.google.Chrome`
- `com.jetbrains.intellij`

## Settings UI

Open settings by right-clicking:

- any app icon, then choose `Settings…`
- empty panel background, then choose `Settings…`

Persisted layout settings:

- left inner padding
- right inner padding
- spacing between icons
- icon size
- dock distance from the left screen edge

Changes are applied live and survive restart.

## Permissions and macOS behavior

- Global hotkeys are registered with Carbon `RegisterEventHotKey`
- Visible-window detection relies on `CGWindowListCopyWindowInfo`
- Exact per-window focusing for cycling uses Accessibility APIs
- If window visibility looks incomplete for some apps, grant Screen Recording access to `mydock` and retry
- If exact window cycling is not working, grant Accessibility access to `mydock`

Practical meaning:

- Without Screen Recording, some apps may expose incomplete window metadata to `CGWindowListCopyWindowInfo`
- Without Accessibility permission, `mydock` still works as an app switcher, but exact window cycling falls back to plain app activation and the cycle cursor does not advance

## Exact Window Focus

To focus a specific window, `mydock` uses a best-effort pipeline:

- activate the target application
- reuse the exact AX window element stored in the runtime cycle state
- raise and focus that AX window
- verify that `kAXFocusedWindowAttribute` now points to the same AX window

Practical meaning:

- `mydock` no longer relies on Core Graphics to Accessibility window matching for cycle focus
- This is more reliable for apps like IDEA where multiple windows may have identical bounds and empty Core Graphics titles
- Exact focus is still best effort if the app exposes incomplete or unusual Accessibility metadata

## Mission Control behavior

- Entering Mission Control temporarily hides the panel
- Leaving Mission Control restores the panel only if it was visible before Mission Control
- If the user hid the panel manually with `Option+D`, Mission Control does not force it back on

Implementation note:

- Mission Control detection is heuristic-based and uses distributed notifications from the system plus an `activeSpaceDidChange` fallback
- This is practical on current macOS, but not backed by a clean dedicated public Mission Control API

## Architecture

- `AppDelegate`: launches the utility app
- `AppCoordinator`: orchestration layer for refresh, hotkeys, menu actions, settings, and panel wiring
- `DockPanelController`: owns the panel and its context-menu hooks
- `PreferencesWindowController`: native AppKit settings window
- `PreferencesStore`: typed `UserDefaults` persistence for pinned apps and layout settings
- `DockVisibilityController`: separates manual visibility from temporary Mission Control hiding
- `RunningAppsService`: snapshots running apps and resolves installed bundles
- `WindowSnapshotService`: snapshots visible Core Graphics windows
- `AXWindowSnapshotService`: enumerates Accessibility windows for the cycle runtime state
- `WindowOrderTracker`: stores per-app runtime window order
- `AccessibilityPermissionService`: checks and prompts for AX permission when exact focus is needed
- `WindowFocusService`: activates the app and focuses a tracked AX window when possible
- `DockModelBuilder`: merges pinned apps, running apps, and visible-window counts into UI-ready slots
- `AppStateStore`: keeps dock items, dynamic ordering, panel visibility, and live layout settings
- `DockPanelView` / `DockItemView`: AppKit panel UI, context menus, badges, and hover state

## Known limitations

- True historical open order for windows that were already present before `mydock` started is not recoverable from public APIs
- Only windows that have usable Accessibility window entries participate in cycling
- Exact focus is best effort and depends on Accessibility metadata quality for the target app
- Mission Control detection is heuristic-based
- Multi-monitor placement is still basic and uses the current main screen
- There is still no drag-and-drop reordering
- There is still no login-item/autostart support

## Source locations

- Project: [mydock.xcodeproj](/Users/alex/mydock/mydock.xcodeproj)
- Sources root: [mydock](/Users/alex/mydock/mydock)
- Persistence defaults: [AppConfiguration.swift](/Users/alex/mydock/mydock/Models/AppConfiguration.swift)
- Layout settings model: [DockLayoutSettings.swift](/Users/alex/mydock/mydock/Models/DockLayoutSettings.swift)
- Window identity model: [WindowIdentity.swift](/Users/alex/mydock/mydock/Models/WindowIdentity.swift)
- Window cycle state: [WindowCycleState.swift](/Users/alex/mydock/mydock/Models/WindowCycleState.swift)
- Preferences persistence: [PreferencesStore.swift](/Users/alex/mydock/mydock/Services/PreferencesStore.swift)
- Visibility coordination: [DockVisibilityController.swift](/Users/alex/mydock/mydock/Services/DockVisibilityController.swift)
- AX cycle source: [AXWindowSnapshotService.swift](/Users/alex/mydock/mydock/Services/AXWindowSnapshotService.swift)
- Window order tracking: [WindowOrderTracker.swift](/Users/alex/mydock/mydock/Services/WindowOrderTracker.swift)
- Accessibility permission check: [AccessibilityPermissionService.swift](/Users/alex/mydock/mydock/Services/AccessibilityPermissionService.swift)
- Exact window focus: [WindowFocusService.swift](/Users/alex/mydock/mydock/Services/WindowFocusService.swift)
