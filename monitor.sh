#!/bin/bash

# Monitor the conversion progress
while true; do
    count=$(ls -1 converted_log/*.mjai 2>/dev/null | wc -l)
    total=184426
    percentage=$((count * 100 / total))
    
    echo "$(date): $count/$total files converted ($percentage%)"
    
    # Show recent log entries
    echo "Recent activity:"
    tail -3 batch_conversion.log
    echo "---"

    sleep 10  # Check every 10 seconds
done