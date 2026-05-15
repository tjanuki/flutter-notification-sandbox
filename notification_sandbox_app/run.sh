#!/bin/bash

# Notification Sandbox - Flutter App Runner
# Usage: ./run.sh [--clean] [-d <device_id>]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLEAN=false
DEVICE_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            CLEAN=true
            shift
            ;;
        -d|--device-id)
            DEVICE_ARGS+=(-d "$2")
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--clean] [-d <device_id>]"
            echo "  --clean         Run 'flutter clean' before building"
            echo "  -d <device_id>  Pass device id to 'flutter run'"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

cd "$(dirname "$0")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Notification Sandbox Flutter App${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$CLEAN" = true ]; then
    echo -e "${GREEN}[1/3]${NC} Running flutter clean..."
    flutter clean || exit 1
else
    echo -e "${YELLOW}[1/3]${NC} Skipping flutter clean (pass --clean to enable)"
fi

echo -e "${GREEN}[2/3]${NC} Fetching dependencies..."
flutter pub get || exit 1

echo -e "${GREEN}[3/3]${NC} Starting Flutter app..."
echo -e "${YELLOW}----------------------------------------${NC}"
echo -e "Press ${RED}q${NC} in the Flutter console to quit"
echo ""

exec flutter run "${DEVICE_ARGS[@]}"
