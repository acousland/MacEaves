#!/bin/bash

# Simple MacEaves Threading Test Script
# Run this script while the app is running to test for threading issues

echo "🧪 MacEaves Threading Test Script"
echo "=================================="
echo ""

# Function to test if app is running
check_app_running() {
    if pgrep -x "MacEaves" > /dev/null; then
        echo "✅ MacEaves app is running"
        return 0
    else
        echo "❌ MacEaves app is not running - please start the app first"
        return 1
    fi
}

# Function to monitor console logs
monitor_logs() {
    echo "🔍 Monitoring console logs for threading issues..."
    echo "   Looking for: dispatch_assert_queue_fail, threading violations, crashes"
    echo "   Press Ctrl+C to stop monitoring"
    echo ""
    
    # Monitor system logs for dispatch queue assertions and crashes
    log stream --predicate 'process == "MacEaves"' --style syslog 2>/dev/null | while read line; do
        echo "$line" | grep -i -E "(dispatch|queue|assert|fail|crash|abort|violation)" && echo "⚠️  POTENTIAL ISSUE DETECTED: $line"
    done
}

# Function to test audio switching stress
test_audio_switching() {
    echo "🎚️ Audio Switching Stress Test"
    echo "   Instructions:"
    echo "   1. Open the Audio Monitor tab in MacEaves"
    echo "   2. Rapidly switch between Input/Output modes"
    echo "   3. Quickly change audio devices"
    echo "   4. Start/stop monitoring repeatedly"
    echo "   5. Watch for any crashes or assertion failures"
    echo ""
    echo "   This test should reveal dispatch queue assertion issues"
    echo "   Press Enter when you've completed the stress test..."
    read
}

# Function to check for crash logs
check_crash_logs() {
    echo "💥 Checking for recent crash logs..."
    
    # Check for crash logs in the last hour
    find ~/Library/Logs/DiagnosticReports -name "*MacEaves*" -mtime -1 2>/dev/null | while read crashlog; do
        echo "📄 Found crash log: $crashlog"
        echo "   Last few lines:"
        tail -10 "$crashlog" | grep -E "(dispatch|queue|assert|thread)" && echo "   ⚠️  Threading-related crash detected!"
    done
    
    # Also check system crash reporter
    if ls /Library/Logs/DiagnosticReports/*MacEaves* 2>/dev/null; then
        echo "📄 System crash logs found - check /Library/Logs/DiagnosticReports/"
    fi
}

# Function to test console output for threading
test_console_output() {
    echo "📊 Testing Console Output for Threading Info..."
    echo "   This will show any threading-related output from the app"
    echo ""
    
    # Capture app output for 10 seconds
    timeout 10 log stream --predicate 'process == "MacEaves"' --style compact 2>/dev/null | grep -i -E "(thread|queue|main|background|dispatch)" || echo "   No threading output detected in 10 seconds"
}

# Main menu
main_menu() {
    echo "Select a test to run:"
    echo "1) Monitor live console logs for threading issues"
    echo "2) Audio switching stress test instructions"
    echo "3) Check for recent crash logs"
    echo "4) Test console output for threading info"
    echo "5) All tests"
    echo "q) Quit"
    echo ""
    echo -n "Enter choice: "
    read choice
    
    case $choice in
        1) monitor_logs ;;
        2) test_audio_switching ;;
        3) check_crash_logs ;;
        4) test_console_output ;;
        5) 
            test_console_output
            echo ""
            test_audio_switching
            echo ""
            check_crash_logs
            echo ""
            echo "Starting log monitoring (Ctrl+C to stop)..."
            monitor_logs
            ;;
        q) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice"; main_menu ;;
    esac
}

# Main execution
if check_app_running; then
    echo ""
    main_menu
else
    echo ""
    echo "Please start MacEaves and then run this script again."
    exit 1
fi
