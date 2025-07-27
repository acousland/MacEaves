#!/bin/bash

# Debug Transcription Test Script
# This script will build and run the app with debug output

echo "🔍 MacEaves Transcription Debug Script"
echo "======================================"

# Set working directory
cd /Users/acousland/Documents/Code/MacEaves

# Build the project
echo "🔨 Building project..."
xcodebuild -project MacEaves.xcodeproj -scheme MacEaves -derivedDataPath ./DerivedData build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Check if the app exists
    if [ -f "DerivedData/Build/Products/Debug/MacEaves.app/Contents/MacOS/MacEaves" ]; then
        echo "🚀 Launching app with debug output..."
        
        # Run the app with debugging enabled
        # This will show console output and crash logs
        MALLOC_STACK_LOGGING=1 MALLOC_SCRIBBLE=1 \
        DerivedData/Build/Products/Debug/MacEaves.app/Contents/MacOS/MacEaves &
        
        APP_PID=$!
        echo "📱 App launched with PID: $APP_PID"
        echo "💡 Watch for crash logs in Console.app or use 'sudo dtruss -p $APP_PID' for system call tracing"
        echo "💡 Press Ctrl+C to stop monitoring"
        
        # Monitor the process
        while kill -0 $APP_PID 2>/dev/null; do
            sleep 1
        done
        
        echo "❌ App process ended"
        
        # Check for crash logs
        echo "🔍 Checking for recent crash logs..."
        find ~/Library/Logs/DiagnosticReports -name "*MacEaves*" -newermt "5 minutes ago" 2>/dev/null | head -5
        
    else
        echo "❌ App binary not found at expected location"
    fi
else
    echo "❌ Build failed!"
    exit 1
fi
