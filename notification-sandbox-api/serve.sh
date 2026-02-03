#!/bin/bash

# Notification Sandbox - Development Server Script
# Starts Laravel API, Reverb WebSocket, and Queue Worker

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Store PIDs for cleanup
PIDS=()

cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
    done
    wait
    echo -e "${GREEN}All services stopped.${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

cd "$(dirname "$0")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Notification Sandbox Dev Server${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Start Laravel API Server
echo -e "${GREEN}[1/3]${NC} Starting Laravel API server on port 8000..."
php artisan serve --host=0.0.0.0 --port=8000 2>&1 | sed 's/^/[API] /' &
PIDS+=($!)
sleep 1

# Start Reverb WebSocket Server
echo -e "${GREEN}[2/3]${NC} Starting Reverb WebSocket server on port 8085..."
php artisan reverb:start 2>&1 | sed 's/^/[WS]  /' &
PIDS+=($!)
sleep 1

# Start Queue Worker
echo -e "${GREEN}[3/3]${NC} Starting Queue Worker..."
php artisan queue:work --tries=3 2>&1 | sed 's/^/[Q]   /' &
PIDS+=($!)

echo ""
echo -e "${GREEN}All services started!${NC}"
echo -e "${YELLOW}----------------------------------------${NC}"
echo -e "  API Server:    ${BLUE}http://localhost:8000${NC}"
echo -e "  WebSocket:     ${BLUE}ws://localhost:8085${NC}"
echo -e "  Queue Worker:  ${BLUE}Running${NC}"
echo -e "${YELLOW}----------------------------------------${NC}"
echo -e "Press ${RED}Ctrl+C${NC} to stop all services"
echo ""

# Wait for all background processes
wait
