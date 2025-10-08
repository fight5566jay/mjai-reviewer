#!/bin/bash

# Script to compress .mjai files to .json.gz format
# Each .mjai file will be compressed individually

echo "Starting compression of .mjai files to .json.gz format..."

# Count total files
total_files=$(find converted_logs/ -name "*.mjai" | wc -l)
echo "Total files to compress: $total_files"

# Counter for progress
count=0
start_time=$(date +%s)

# Create output directory for compressed files
output_dir="converted_logs_compressed"
mkdir -p "$output_dir"

# Process files in batches to avoid overwhelming the system
find converted_logs/ -name "*.mjai" -print0 | while IFS= read -r -d '' file; do
    # Extract filename without path and extension
    basename=$(basename "$file" .mjai)
    
    # Define output file path
    output_file="$output_dir/${basename}.json.gz"
    
    # Skip if already exists
    if [[ -f "$output_file" ]]; then
        ((count++))
        if ((count % 1000 == 0)); then
            echo "[$count/$total_files] SKIP: $basename (already exists)"
        fi
        continue
    fi
    
    # Compress the file (rename from .mjai to .json during compression)
    if gzip -c "$file" > "$output_file"; then
        ((count++))
        
        # Progress update every 100 files
        if ((count % 100 == 0)); then
            current_time=$(date +%s)
            elapsed=$((current_time - start_time))
            rate=$((count * 60 / elapsed))
            echo "[$count/$total_files] Compressed: $basename (Rate: $rate files/min)"
        fi
    else
        echo "ERROR: Failed to compress $file"
    fi
    
    # Progress summary every 1000 files
    if ((count % 1000 == 0)); then
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        hours=$((elapsed / 3600))
        minutes=$(((elapsed % 3600) / 60))
        echo "=== Progress Update ==="
        echo "Completed: $count/$total_files ($(echo "scale=2; $count * 100 / $total_files" | bc)%)"
        echo "Elapsed time: ${hours}h ${minutes}m"
        echo "=================="
    fi
done

echo "=== COMPRESSION COMPLETED ==="
final_count=$(find "$output_dir" -name "*.json.gz" | wc -l)
echo "Total compressed files: $final_count"
echo "Original directory size: $(du -sh converted_logs/ | cut -f1)"
echo "Compressed directory size: $(du -sh $output_dir/ | cut -f1)"
echo "Done!"