#!/bin/bash
# Stop MacSpace.
pkill -f "MacSpace --port" && echo "MacSpace stopped" || echo "MacSpace was not running"
