#!/bin/bash

# Parse command line arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <input_txt_file> <output_directory> [batch_size]"
    echo "Example: $0 tenhou_log_urls/log_htmls/tenhou_log_urls_2024_1.txt converted_logs 50"
    exit 1
fi

txt_file="$1"
output_dir="$2"
batch_size="${3:-100}"  # Default batch size for progress updates

# Validate input file exists
if [[ ! -f "$txt_file" ]]; then
    echo "ERROR: Input file '$txt_file' not found!"
    exit 1
fi

echo "Starting EFFICIENT MJAI conversion (single container)..."
echo "Input file: $txt_file"
echo "Output directory: $output_dir"
echo "Progress update every: $batch_size files"

# Ensure output directory exists
mkdir -p "$output_dir"

# Create mjai file directory
mjai_dir="converted_logs"
mkdir -p "$mjai_dir"

# Create clean temp file
clean_file="temp_clean_urls.txt"
tr -d '\r' < "$txt_file" > "$clean_file"

# Count total URLs
total_urls=$(wc -l < "$clean_file")
echo "Total URLs to process: $total_urls"

echo "Starting single container for batch processing..."

# Create a script to run inside the container
cat > batch_convert.sh << EOF
#!/bin/bash

# This script runs INSIDE the container
# Container starts in /mjai-reviewer, workspace is mounted at /workspace

count=0
failed_log_id_extraction=0
skipped=0
converted=0
failed_conversion=0
compressed=0
failed_compression=0
batch_size=$batch_size

echo "Container started, beginning batch processing..."
echo "Current directory: \$(pwd)"
echo "Current files in output directory: \$(ls -1 /workspace/$output_dir | wc -l)"
echo "Temp file exists: \$(ls -la /workspace/temp_clean_urls.txt 2>/dev/null || echo 'NOT FOUND')"

while IFS= read -r url; do
    echo "DEBUG: Read URL: '\$url'"
    [[ -z "\$url" ]] && { echo "DEBUG: Empty URL, skipping"; continue; }
    
    ((count++))
    echo "DEBUG: Processing count=\$count, url=\$url"
    
    # Extract log ID
    log_id=\$(echo "\$url" | sed 's/.*log=\([^&]*\).*/\1/')
    
    if [[ -z "\$log_id" ]]; then
        echo "[\$count] ERROR: Could not extract log ID from: \$url"
        ((failed_log_id_extraction++))
        continue
    fi
    
    mjai_file="$mjai_dir/\${log_id}.mjai"
    output_file="$output_dir/\${log_id}.json.gz"

    # Check if already exists
    if [[ -f "/workspace/\$output_file" ]]; then
        ((skipped++))
        echo "[\$count] SKIP: \$log_id (already exists)"
        continue
    fi
    
    # Progress update every 10 files
    if ((count % 10 == 0)) || ((count <= 5)); then
        echo "[\$count] Processing: \$log_id"
    fi
    
    # Convert using mjai-reviewer directly (no container overhead)
    if ./target/release/mjai-reviewer \
        -e akochan \
        --no-open \
        --no-review \
        -u "\$url" \
        --mjai-out "/workspace/\$mjai_file" >/dev/null 2>&1; then
        
        ((converted++))
        if ((count % 10 == 0)) || ((count <= 5)); then
            echo "[\$count] CONVERTED: \$log_id"
        fi

        # Compress the mjai to json.gz
        if gzip -c "/workspace/\$mjai_file" > "/workspace/\$output_file"; then
            ((compressed++))
            echo "[\$count] COMPRESSED: \${log_id}.json.gz"
        else
            ((failed_compression++))
            echo "[\$count] FAILED (COMPRESS): \$log_id"
        fi
    else
        ((failed_conversion++))
        echo "[\$count] FAILED (CONVERT): \$log_id"
    fi
    
    # Progress summary every batch_size files
    if ((count % \$batch_size == 0)); then
        echo "=== Progress Update ==="
        echo "Processed: \$count"
        echo "Converted: \$converted"
        echo "Failed conversion: \$failed_conversion"
        echo "Compressed: \$compressed"
        echo "Failed compression: \$failed_compression"
        echo "Skipped: \$skipped"
        echo "Failed log id extraction: \$failed_log_id_extraction"
        echo "=================="
    fi
    
done < /workspace/temp_clean_urls.txt

echo "=== FINAL SUMMARY ==="
echo "Total processed: \$count"
echo "Converted: \$converted"
echo "Failed conversion: \$failed_conversion"
echo "Compressed: \$compressed"
echo "Failed compression: \$failed_compression"
echo "Skipped: \$skipped"
echo "Failed log id extraction: \$failed_log_id_extraction"
echo "Done!"
EOF

chmod +x batch_convert.sh

# Run the container once with the batch script
echo "Launching container for batch processing..."
podman run --rm \
    --entrypoint /bin/bash \
    -v /mnt/nfs/work/sctang/Projects/mjai-reviewer-copy:/workspace \
    localhost/mjai-reviewer \
    /workspace/batch_convert.sh

# Clean up
#rm -f "$clean_file" batch_convert.sh

echo "Batch conversion completed!"