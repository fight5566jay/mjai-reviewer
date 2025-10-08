#!/bin/bash

txt_file="tenhou_log_urls/log_htmls/tenhou_log_urls_2024_1.txt"
output_dir="converted_logs"

echo "Starting MJAI conversion..."
echo "Input file: $txt_file"
echo "Output directory: $output_dir"

# Ensure output directory exists
mkdir -p "$output_dir"

# Create clean temp file
clean_file="temp_clean_urls.txt"
tr -d '\r' < "$txt_file" > "$clean_file"

# Count total URLs
total_urls=$(wc -l < "$clean_file")
echo "Total URLs to process: $total_urls"

# Initialize counters
count=0
success=0
failed=0

echo "Starting processing loop..."

# Read from clean file
while IFS= read -r url; do
    # Skip empty lines
    [[ -z "$url" ]] && continue
    
    ((count++))
    
    # Extract log ID
    log_id=$(echo "$url" | sed 's/.*log=\([^&]*\).*/\1/')
    
    if [[ -z "$log_id" ]]; then
        echo "[$count/$total_urls] ERROR: Could not extract log ID from: $url"
        ((failed++))
        continue
    fi
    
    output_file="$output_dir/${log_id}.mjai"
    
    # Check if already exists
    if [[ -f "$output_file" ]]; then
        echo "[$count/$total_urls] SKIP: $log_id (already exists)"
        continue
    fi
    
    # Progress update
    echo "[$count/$total_urls] Processing: $log_id"
    
    # Convert
    if podman run --rm \
        -v /mnt/nfs/work/sctang/Projects/mjai-reviewer:/workspace \
        localhost/mjai-reviewer \
        -e akochan \
        --no-open \
        --no-review \
        -u "$url" \
        --mjai-out "/workspace/$output_file" >/dev/null 2>&1; then
        
        ((success++))
        echo "[$count/$total_urls] SUCCESS: $log_id"
    else
        ((failed++))
        echo "[$count/$total_urls] FAILED: $log_id"
    fi
    
done < "$clean_file"

# Clean up
rm -f "$clean_file"

echo "=== FINAL SUMMARY ==="
echo "Total processed: $count"
echo "Successful: $success"
echo "Failed: $failed"
echo "Done!"