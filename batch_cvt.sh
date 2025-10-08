#!/bin/bash

# Parse command line arguments
if [[ $# -lwhile IFS= read -r url; do
    echo "DEBUG: Read URL: '\$url'"
    [[ -z "\$url" ]] && { echo "DEBUG: Empty URL, skipping"; continue; }
    
    ((count++))
    echo "DEBUG: Processing count=\$count, url=\$url"]]; then
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
cd /workspace

count=0
success=0
failed=0
batch_size=$batch_size

echo "Container started, beginning batch processing..."
echo "Current directory: \$(pwd)"
echo "Temp file exists: \$(ls -la temp_clean_urls.txt 2>/dev/null || echo 'NOT FOUND')"
echo "First few lines of temp file:"
head -3 temp_clean_urls.txt 2>/dev/null || echo "Cannot read temp file"

while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    
    ((count++))
    
    # Extract log ID
    log_id=\$(echo "\$url" | sed 's/.*log=\([^&]*\).*/\1/')
    
    if [[ -z "\$log_id" ]]; then
        echo "[\$count] ERROR: Could not extract log ID from: \$url"
        ((failed++))
        continue
    fi
    
    output_file="$output_dir/\${log_id}.mjai"
    
    # Check if already exists
    if [[ -f "\$output_file" ]]; then
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
        --mjai-out "/workspace/\$output_file" >/dev/null 2>&1; then
        
        ((success++))
        if ((count % 10 == 0)) || ((count <= 5)); then
            echo "[\$count] SUCCESS: \$log_id"
        fi
    else
        ((failed++))
        echo "[\$count] FAILED: \$log_id"
    fi
    
    # Progress summary every batch_size files
    if ((count % \$batch_size == 0)); then
        echo "=== Progress Update ==="
        echo "Processed: \$count"
        echo "Successful: \$success"
        echo "Failed: \$failed"
        echo "=================="
    fi
    
done < temp_clean_urls.txt

echo "=== FINAL SUMMARY ==="
echo "Total processed: \$count"
echo "Successful: \$success"
echo "Failed: \$failed"
echo "Done!"
EOF

chmod +x batch_convert.sh

# Run the container once with the batch script
echo "Launching container for batch processing..."
podman run --rm \
    --entrypoint /bin/bash \
    -v /mnt/nfs/work/sctang/Projects/mjai-reviewer:/workspace \
    localhost/mjai-reviewer \
    /workspace/batch_convert.sh

# Clean up
rm -f "$clean_file" batch_convert.sh

echo "Batch conversion completed!"