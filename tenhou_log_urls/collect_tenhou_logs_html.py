#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import re
from pathlib import Path

# Configuration
DEFAULT_HTML_DIR = "html_files"
DEFAULT_OUTPUT_DIR = "log_htmls"
SEARCH_KEYWORD = "四鳳南喰赤"
URL_PATTERN = r'http://tenhou\.net/0/\?log=[^\s"<>]+'

def extract_year_from_url(url):
    """Extract the year from tenhou URL (e.g., log=2024... -> 2024)."""
    match = re.search(r'log=(\d{4})', url)
    return match.group(1) if match else "unknown"

def get_output_filename(urls, output_dir):
    """Generate output filename based on year and file_id."""
    if not urls:
        return os.path.join(output_dir, "tenhou_log_urls_unknown_1.txt")
    
    # Extract year from first URL
    year = extract_year_from_url(urls[0])
    
    # Find next available file_id
    file_id = 1
    while True:
        filename = os.path.join(output_dir, f"tenhou_log_urls_{year}_{file_id}.txt")
        if not os.path.exists(filename):
            return filename
        file_id += 1

def extract_urls_from_file(filepath):
    """Extract URLs from a single HTML file that contain the keyword."""
    urls = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                # Check if line contains the keyword
                if SEARCH_KEYWORD in line:
                    # Find all matching URLs in this line
                    found_urls = re.findall(URL_PATTERN, line)
                    if found_urls:
                        print(f"  Line {line_num}: Found {len(found_urls)} URL(s)")
                        urls.extend(found_urls)
    except Exception as e:
        print(f"  [ERROR] Failed to read file: {e}")
    
    return urls

def main():
    # Parse command line arguments
    if len(sys.argv) > 1:
        html_dir = sys.argv[1]
    else:
        html_dir = DEFAULT_HTML_DIR
    
    if len(sys.argv) > 2:
        output_dir = sys.argv[2]
    else:
        output_dir = DEFAULT_OUTPUT_DIR
    
    # Custom output file path can be specified as third parameter
    custom_output = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    print("=" * 60)
    print("Extracting Tenhou URLs from HTML files")
    print("=" * 60)
    print(f"Keyword: {SEARCH_KEYWORD}")
    print(f"HTML directory: {html_dir}")
    print(f"Output directory: {output_dir}")
    if custom_output:
        print(f"Output file: {custom_output} (custom)")
    else:
        print(f"Output file: (auto-generated based on year)")
    print()
    
    # Check if HTML directory exists
    html_path = Path(html_dir)
    if not html_path.exists():
        print(f"ERROR: Directory '{html_dir}' not found!")
        print("Please run the extraction script first.")
        return
    
    # Get all HTML files
    html_files = list(html_path.glob("*.html"))
    if not html_files:
        print(f"ERROR: No HTML files found in '{html_dir}'")
        return
    
    print(f"Found {len(html_files)} HTML file(s)")
    print()
    
    # Process each file
    all_urls = []
    for html_file in sorted(html_files):
        print(f"Processing: {html_file.name}")
        urls = extract_urls_from_file(html_file)
        if urls:
            all_urls.extend(urls)
            print(f"  Total URLs found in this file: {len(urls)}")
        else:
            print(f"  No matching URLs found")
        print()
    
    # Write all URLs to output file
    if all_urls:
        # Generate output filename if not specified
        if custom_output:
            output_file = custom_output
        else:
            output_file = get_output_filename(all_urls, output_dir)
            print(f"Generated output filename: {os.path.basename(output_file)}")
            print()
        
        with open(output_file, 'w', encoding='utf-8') as f:
            for url in all_urls:
                f.write(url + '\n')
        
        print("=" * 60)
        print("Extraction complete!")
        print("=" * 60)
        print(f"Total URLs extracted: {len(all_urls)}")
        print(f"Output saved to: {output_file}")
        print()
        
        # Show first few URLs as preview
        preview_count = min(5, len(all_urls))
        print(f"Preview (first {preview_count} URLs):")
        for url in all_urls[:preview_count]:
            print(f"  {url}")
        if len(all_urls) > preview_count:
            print(f"  ... and {len(all_urls) - preview_count} more")
    else:
        print("=" * 60)
        print("No URLs found!")
        print("=" * 60)
        print(f"No lines containing '{SEARCH_KEYWORD}' with matching URLs were found.")
    
    print()
    #input("Press Enter to exit...")

if __name__ == "__main__":
    main()