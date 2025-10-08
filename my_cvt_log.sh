#!/bin/bash

# Script to convert all Tenhou logs to MJAI format using mjai-reviewer
# URLs are stored in tenhou_log_urls/log_htmls/*.txt files

set -e  # Exit on any error

# Create output directory
mkdir -p converted_logs

# Initialize counters
total_files=0
processed_files=0
failed_files=0
skipped_files=0

# Function to extract log ID from Tenhou URL
extract_log_id() {
    local url="$1"
    echo "$url" | grep -o 'log=[^&]*' | cut -d'=' -f2
}

# Function to convert a single URL
convert_log() {
    local url="$1"
    local log_id
    local output_file
    
    log_id=$(extract_log_id "$url")
    if [[ -z "$log_id" ]]; then
        echo "ERROR: Could not extract log ID from URL: $url"
        return 1
    fi
    
    output_file="converted_logs/${log_id}.mjai"
    
    # Skip if file already exists
    if [[ -f "$output_file" ]]; then
        echo "SKIP: $output_file already exists"
        ((skipped_files++))
        return 0
    fi
    
    echo "Converting: $log_id"
    
    # Run mjai-reviewer to convert the log
    if podman run --rm \
        -v /mnt/nfs/work/sctang/Projects/mjai-reviewer:/workspace \
        localhost/mjai-reviewer \
        -e akochan \
        --no-open \
        --no-review \
        -u "$url" \
        --mjai-out "/workspace/$output_file" 2>/dev/null; then
        
        echo "SUCCESS: $log_id -> $output_file"
        ((processed_files++))
        return 0
    else
        echo "FAILED: $log_id"
        ((failed_files++))
        return 1
    fi
}

# Main processing loop
echo "Starting conversion of Tenhou logs to MJAI format..."
echo "Output directory: converted_logs/"
echo

# Process all .txt files in tenhou_log_urls/log_htmls/
for txt_file in tenhou_log_urls/log_htmls/*.txt; do
    if [[ ! -f "$txt_file" ]]; then
        echo "No .txt files found in tenhou_log_urls/log_htmls/"
        exit 1
    fi
    
    echo "Processing file: $txt_file"
    file_total=$(wc -l < "$txt_file")
    echo "Total URLs in file: $file_total"
    
    # Read URLs line by line
    line_num=0
    while IFS= read -r url; do
        ((line_num++))
        ((total_files++))
        
        # Remove any carriage returns or whitespace
        url=$(echo "$url" | tr -d '\r' | xargs)
        
        # Skip empty lines
        [[ -z "$url" ]] && continue
        
        # Progress indicator - show every 10 instead of every 100
        if ((line_num % 10 == 0)) || ((line_num <= 5)); then
            echo "Progress: $line_num/$file_total ($((line_num * 100 / file_total))%) - Processing: $url"
        fi
        
        # Convert the log
        convert_log "$url" || true  # Continue on error
        
    done < <(tr -d '\r' < "$txt_file")
    
    echo "Finished processing: $txt_file"
    echo
done

# Final summary
echo "=== CONVERSION SUMMARY ==="
echo "Total URLs processed: $total_files"
echo "Successfully converted: $processed_files"
echo "Failed conversions: $failed_files"
echo "Skipped (already exist): $skipped_files"
echo "Output directory: converted_logs/"
echo "Done!"