# swift-openapi-mock

By [Ron Tech](https://rontech.es)

Record and replay API responses for apps built with [swift-openapi-generator](https://github.com/apple/swift-openapi-generator).

---

## Why

Every existing iOS mocking library (OHHTTPStubs, Mocker, MockDuck) operates at the URLSession level — they match on full URLs and have no awareness of OpenAPI operations. This means you need a separate file for every path parameter variation (`/events/1`, `/events/2`, `/events/3`...).

`OpenAPIMock` hooks into the `ClientMiddleware` layer and uses `operationID` as the match key. One file covers all variations of the same operation.

| | OHHTTPStubs / Mocker / MockDuck | OpenAPIMock |
|---|---|---|
| Match key | Full URL | `operationID` |
| Path param variations | One file per value | One file for all |
| Integration layer | URLSession | ClientMiddleware |
| Record real responses | ❌ | ✅ |
| Works with swift-openapi-generator | ❌ | ✅ |

---

## Workflow

```
1. Enable RecordingClientMiddleware → run the app → real responses saved to simulator
2. Run export script → JSON files copied into your project
3. Commit JSON files
4. Enable MockClientMiddleware → app runs fully offline
```

---

## Installation

Add the package in Xcode via **File → Add Package Dependencies** or in `Package.swift`:

```swift
.package(url: "https://github.com/rontech-es/swift-openapi-mock", from: "0.1.0")
```

Then add `OpenAPIMock` to your target dependencies.

---

## Quick start

```swift
import OpenAPIMock

let mock = MockClientMiddleware(isEnabled: true)
let recorder = RecordingClientMiddleware(isEnabled: false)

// mock must come before recorder — if a file is found, the request never reaches recorder
let client = Client(
    serverURL: baseURL,
    transport: transport,
    middlewares: [mock, recorder]
)
```

---

## Cookbook

### Connect to a debug menu

The framework owns no opinion on how flags are managed. Pass a `Bool` from wherever your debug state lives — `UserDefaults`, `@AppStorage`, a launch argument, or hardcoded.

```swift
let mock = MockClientMiddleware(
    isEnabled: UserDefaults.standard.bool(forKey: "isMockingEnabled")
)
let recorder = RecordingClientMiddleware(
    isEnabled: UserDefaults.standard.bool(forKey: "isRecordingEnabled")
)
```

### Use in XCTest / Swift Testing

Pass `.zero` latency so tests don't wait.

```swift
let mock = MockClientMiddleware(
    isEnabled: true,
    simulatedLatency: .zero,
    bundle: .module,
    subdirectory: "MockResponses"
)
```

### Mock only some endpoints

If no file is found for an operation, the request falls through to the real network automatically. You don't need to configure anything — just don't provide a file for the operations you want to hit live.

### Silence console output

```swift
let mock = MockClientMiddleware(isEnabled: true, verbose: false)
let recorder = RecordingClientMiddleware(isEnabled: true, verbose: false)
```

### Export recorded files

After recording, `RecordingClientMiddleware` prints the simulator path for each saved file:

```
✅ [OpenAPIMock] Recorded 'api_events_list' → /Users/.../Documents/MockResponses/api_events_list.json
```

Copy the script below into your project as `Scripts/export-mock-responses.sh`, then run it to pull all recorded files into your project:

```bash
./Scripts/export-mock-responses.sh \
  --simulator-path "/path/to/simulator/Documents/MockResponses" \
  --project-path "./MyApp/MockResponses"
```

<details>
<summary>export-mock-responses.sh</summary>

```bash
#!/bin/bash

# export-mock-responses.sh
# Copies recorded JSON mock files from the iOS Simulator to your project.
#
# Usage:
#   ./Scripts/export-mock-responses.sh \
#     --simulator-path "/path/to/simulator/Documents/MockResponses" \
#     --project-path "./MyApp/MockResponses"
#
# The simulator path is printed to the console by RecordingClientMiddleware
# after each recorded response.

set -e

SIMULATOR_PATH=""
PROJECT_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --simulator-path)
            SIMULATOR_PATH="$2"
            shift 2
            ;;
        --project-path)
            PROJECT_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 --simulator-path <path> --project-path <path>"
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$SIMULATOR_PATH" || -z "$PROJECT_PATH" ]]; then
    echo "Usage: $0 --simulator-path <path> --project-path <path>"
    echo ""
    echo "  --simulator-path   Path to MockResponses in the simulator (printed by RecordingClientMiddleware)"
    echo "  --project-path     Destination folder in your project"
    exit 1
fi

# Validate simulator path exists
if [[ ! -d "$SIMULATOR_PATH" ]]; then
    echo "❌ Simulator path not found: $SIMULATOR_PATH"
    echo "   Make sure RecordingClientMiddleware is enabled and you have run the app at least once."
    exit 1
fi

# Find JSON files
JSON_FILES=("$SIMULATOR_PATH"/*.json)
if [[ ! -e "${JSON_FILES[0]}" ]]; then
    echo "⚠️  No JSON files found in: $SIMULATOR_PATH"
    echo "   Make sure RecordingClientMiddleware is enabled and you have made at least one API call."
    exit 0
fi

# Create destination if needed
mkdir -p "$PROJECT_PATH"

# Copy files
COUNT=0
for FILE in "${JSON_FILES[@]}"; do
    FILENAME=$(basename "$FILE")
    cp "$FILE" "$PROJECT_PATH/$FILENAME"
    echo "✅ $FILENAME"
    COUNT=$((COUNT + 1))
done

echo ""
echo "Exported $COUNT file(s) to $PROJECT_PATH"
```

</details>

After exporting, add the `MockResponses/` folder to your Xcode target so files are bundled with the app.

---

## Requirements

- iOS 16+ / macOS 13+
- Swift 5.9+
- [swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime) 1.0+

---

## License

MIT — see [LICENSE](LICENSE)

---

Built with ❤️ by [Ron Tech](https://rontech.es)
