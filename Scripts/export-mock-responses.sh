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
