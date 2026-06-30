# JWTee

A native macOS app for inspecting JSON Web Tokens — like jwt.io, but your
secret never leaves your machine.

- **Decode**: paste a JWT, see header + payload pretty-printed.
- **Inspect**: highlighted claims (alg, issuer, subject, audience, iat/nbf/exp)
  and expiry / not-yet-valid status.
- **Verify**: provide a secret and check the HMAC signature (HS256/384/512),
  entirely offline. The secret stays local.

## Layout

The same source folders are built two equivalent ways — an Xcode project and a
Swift package.

**Xcode** (`jwtee.xcodeproj`) — produces a real, signed macOS `.app`:

| Target | What it is |
| --- | --- |
| `JWTCore` (framework) | All JWT logic — decoding, claim extraction, HMAC verification, and the display model. Pure, no UI. |
| `jwtee` (app) | Thin SwiftUI front-end; links & embeds `JWTCore`. |
| `jwteeTests` (unit tests) | The test suite (below), swift-testing with `@testable import JWTCore`. |

```sh
open jwtee.xcodeproj     # ⌘R to run, ⌘U to test
```

**Swift package** (`Package.swift`) — fast CLI path:

| Target | Command |
| --- | --- |
| `JWTCore` (library) | shared sources |
| `JWTeeApp` (executable) | `swift run jwtee` |
| `JWTCoreTests` | `swift test` |

Keeping the logic in `JWTCore` is what makes it testable without a UI.

## Running the tests

The behavior is covered by 38 tests (one is parameterized over HS384/HS512),
written with Apple's [swift-testing](https://developer.apple.com/documentation/testing).
In Xcode press **⌘U** (or use the Test navigator); from the CLI:

```sh
swift test
```

> If `swift test` reports `no such module 'Testing'`, the active developer
> directory is pointing at the Command Line Tools rather than Xcode. Fix with:
> ```sh
> sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
> ```

What's covered:
- base64url encode/decode round-trips and rejection of bad input
- structural decoding + malformed-token errors (segment count, bad base64,
  non-JSON, non-object)
- HS256 against the canonical jwt.io token (external ground truth)
- HS384 / HS512 sign-and-verify round trips
- wrong secret, tampered payload, unsupported `alg` (RS256, `none`)
- UTF-8 vs base64 secret encodings
- `exp` / `nbf` validity (with injected clock), `aud` string-vs-array, etc.

## Building / running the app

In Xcode, open `jwtee.xcodeproj` and press **⌘R**. The `jwtee` target builds a
signed `.app` (it links and embeds the `JWTCore.framework`). From the CLI:

```sh
xcodebuild -scheme jwtee -destination 'platform=macOS' build   # real .app
swift run jwtee                                                # quick dev run
```

To distribute (icon, notarization), use **Product ▸ Archive** in Xcode.
