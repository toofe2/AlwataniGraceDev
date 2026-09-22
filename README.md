# AlwataniGraceDev

Developer instrumentation project for testing the Alwatani Grace Days client flow on an authorized test account.

## Current stage

This branch builds an ARM64 iOS 15+ tweak/dylib scaffold and displays a developer panel with a free numeric input.

It does **not** bypass server-side validation, authentication, subscription ownership, or eligibility checks.

## Target

- iOS 15+
- ARM64
- TrollStore / TrollFools injection workflow
- Output artifact: `AlwataniGraceDev.dylib`

## Next stage

After confirming the dylib injects and loads cleanly, wire the developer panel to inspect the authorized `/grace-days` request path and display the real server response without overriding server decisions.
