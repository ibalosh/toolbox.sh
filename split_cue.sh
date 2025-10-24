#!/bin/bash

# Script to split FLAC/APE/WV files using CUE sheets into individual tracks
# Supports recursive processing of directories
# Maintains original quality throughout conversion
# Only processes directories that contain .cue files

# Removed set -e to allow script to continue on errors
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

# Function to check if required tools are installed
check_dependencies() {
    local missing_tools=()

    for tool in shnsplit cuebreakpoints flac wvunpack mac; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Install with: brew install flac shntool cuetools mac wavpack"
        exit 1
    fi
}

# Function to convert APE to FLAC
ape_to_flac() {
    local ape_file="$1"
    local flac_file="${ape_file%.ape}.flac"

    print_info "Converting APE to FLAC: $(basename "$ape_file")"

    # Decode APE to WAV
    local temp_wav="${ape_file%.ape}.wav"
    mac "$ape_file" "$temp_wav" -d

    # Encode WAV to FLAC (level 8 compression - lossless, audio is identical)
    flac -8 "$temp_wav" -o "$flac_file"

    # Remove temporary WAV
    rm "$temp_wav"

    echo "$flac_file"
}

# Function to convert WavPack to FLAC
wv_to_flac() {
    local wv_file="$1"
    local flac_file="${wv_file%.wv}.flac"

    print_info "Converting WavPack to FLAC: $(basename "$wv_file")"

    # Decode WV to WAV
    local temp_wav="${wv_file%.wv}.wav"
    wvunpack "$wv_file" -o "$temp_wav"

    # Encode WAV to FLAC (level 8 compression - lossless, audio is identical)
    flac -8 "$temp_wav" -o "$flac_file"

    # Remove temporary WAV
    rm "$temp_wav"

    echo "$flac_file"
}

# Function to split a single file with CUE
split_with_cue() {
    local audio_file="$1"
    local cue_file="$2"

    # Convert to absolute paths immediately
    audio_file="$(cd "$(dirname "$audio_file")" && pwd)/$(basename "$audio_file")"
    cue_file="$(cd "$(dirname "$cue_file")" && pwd)/$(basename "$cue_file")"

    # Get absolute path for working directory
    local working_dir="$(dirname "$audio_file")"
    local base_name="$(basename "$audio_file" | sed 's/\.[^.]*$//')"

    # Store original audio file for moving later (already absolute path)
    local original_audio_file="$audio_file"

    print_info "Processing: $(basename "$audio_file") with $(basename "$cue_file")"

    # Create a temporary directory for split files
    local temp_dir="${working_dir}/.split_temp_$$"
    mkdir -p "$temp_dir"

    # Determine format and convert if needed
    local process_file="$audio_file"
    local cleanup_converted=false

    case "${audio_file##*.}" in
        ape)
            process_file=$(ape_to_flac "$audio_file")
            cleanup_converted=true
            ;;
        wv)
            process_file=$(wv_to_flac "$audio_file")
            cleanup_converted=true
            ;;
        flac)
            # Already FLAC, use as-is
            ;;
        *)
            print_error "Unsupported format: ${audio_file##*.}"
            rm -rf "$temp_dir"
            return 1
            ;;
    esac

    # Split the file using shnsplit
    # Convert paths to absolute paths before changing directory
    local abs_cue_file="$(cd "$(dirname "$cue_file")" && pwd)/$(basename "$cue_file")"
    local abs_process_file="$(cd "$(dirname "$process_file")" && pwd)/$(basename "$process_file")"

    cd "$temp_dir"

    # Use cuebreakpoints to split
    # Using -8 (high compression, still lossless - audio quality is identical)
    if shnsplit -f "$abs_cue_file" -t "%n - %t" -o "flac flac -8 -o %f -" "$abs_process_file"; then
        print_info "Successfully split into tracks"

        # Move split files to the original directory
        for split_file in *.flac; do
            if [ -f "$split_file" ]; then
                # Extract track number from filename and remove leading zeros for printf
                local track_num=$(echo "$split_file" | grep -oE '^[0-9]+' | sed 's/^0*//')
                # Handle empty string (if it was just "0")
                [ -z "$track_num" ] && track_num=0
                # Format track number with leading zero
                local formatted_num=$(printf "%02d" $track_num)
                # Extract title from filename (remove track number prefix and any leading spaces/dashes)
                local title=$(echo "$split_file" | sed -E 's/^[0-9]+ *- *//')

                # Create final filename
                local final_name="${formatted_num} - ${title}"

                # Copy then remove (cp is more reliable than mv across different filesystems)
                cp -f "$split_file" "${working_dir}/${final_name}"
                rm "$split_file"
                print_info "Created: ${final_name}"
            fi
        done

        cd "$working_dir"

        # Create _original subdirectory and move original files there BEFORE cleaning up temp
        local original_dir="${working_dir}/_original"
        mkdir -p "$original_dir"

        # Move original audio file (not the converted one if it was converted)
        if [ -f "$original_audio_file" ]; then
            if mv "$original_audio_file" "$original_dir/" 2>/dev/null; then
                print_info "Moved to _original/: $(basename "$original_audio_file")"
            else
                print_error "Failed to move audio file to _original/"
            fi
        else
            print_warning "Original audio file not found: $original_audio_file"
        fi

        # Move CUE file
        if [ -f "$cue_file" ]; then
            if mv "$cue_file" "$original_dir/" 2>/dev/null; then
                print_info "Moved to _original/: $(basename "$cue_file")"
            else
                print_error "Failed to move CUE file to _original/"
            fi
        else
            print_warning "CUE file not found: $cue_file"
        fi

        # Remove converted file if it was temporary and different from original
        if [ "$cleanup_converted" = true ] && [ -f "$process_file" ]; then
            rm "$process_file"
        fi

        # Clean up temp directory AFTER moving files
        rm -rf "$temp_dir"

        print_info "Split complete! Original files moved to: _original/"
        return 0

    else
        print_error "Failed to split file: $audio_file"
        cd "$working_dir" 2>/dev/null || true
        rm -rf "$temp_dir" 2>/dev/null || true

        # Clean up converted file if it failed
        if [ "$cleanup_converted" = true ] && [ -f "$process_file" ]; then
            rm "$process_file" 2>/dev/null || true
        fi

        return 1
    fi
}

# Function to find and process audio files with CUE sheets
process_directory() {
    local search_dir="$1"
    local success_count=0
    local fail_count=0
    local total_count=0

    print_info "Scanning directory: $search_dir"

    # Create array to store CUE file paths
    local cue_files_array=()

    # Read CUE files into array using absolute paths
    # Exclude _original directories to avoid reprocessing already-moved files
    local IFS=$'\n'
    # Use find with full path and convert to absolute
    local current_dir="$(pwd)"
    cd "$search_dir"
    for cue_file in $(find . -type f -name "*.cue" -not -path "*/_original/*"); do
        # Remove leading ./ and prepend absolute search_dir path
        cue_file="${cue_file#./}"
        cue_files_array+=("$(pwd)/$cue_file")
    done
    cd "$current_dir"

    total_count=${#cue_files_array[@]}

    if [ $total_count -eq 0 ]; then
        print_warning "No CUE files found in: $search_dir"
        return 0
    fi

    print_info "Found $total_count CUE file(s) to process"
    echo ""

    # Process each CUE file
    for cue_file in "${cue_files_array[@]}"; do
        [ -z "$cue_file" ] && continue

        # cue_file is already absolute path
        local dir_path="$(dirname "$cue_file")"
        local cue_base="$(basename "$cue_file" .cue)"

        print_info "Processing CUE file: $(basename "$cue_file") in $(basename "$dir_path")"

        # Look for matching audio file (FLAC, APE, or WV)
        local audio_file=""

        # First try exact match
        for ext in flac ape wv; do
            if [ -f "${dir_path}/${cue_base}.${ext}" ]; then
                audio_file="${dir_path}/${cue_base}.${ext}"
                break
            fi
        done

        # If no exact match, try to find any matching audio file in the directory
        if [ -z "$audio_file" ]; then
            print_info "No exact match found, searching for any audio file in directory..."
            for ext in flac ape wv; do
                # Find first file with matching extension (using absolute path)
                local found_file=$(find "${dir_path}/" -maxdepth 1 -type f -name "*.${ext}" 2>/dev/null | head -n 1)
                if [ -n "$found_file" ]; then
                    audio_file="$found_file"
                    print_info "Found audio file: $(basename "$audio_file")"
                    break
                fi
            done
        fi

        if [ -z "$audio_file" ]; then
            print_warning "No matching audio file found for: $(basename "$cue_file")"
            print_warning "  Looking for: ${cue_base}.{flac,ape,wv}"
            print_warning "  In directory: $dir_path"
            print_warning "  Available audio files:"
            (cd "$dir_path" && ls -1 *.flac *.ape *.wv 2>/dev/null | sed 's/^/    /') || echo "    (none)"
            continue
        fi

        # Process this file (continue even if it fails)
        if split_with_cue "$audio_file" "$cue_file"; then
            print_info "✓ Successfully processed: $(basename "$audio_file")"
            ((success_count++))
        else
            print_error "✗ Failed to process: $(basename "$audio_file") - continuing with next file"
            ((fail_count++))
        fi
        echo ""
    done

    # Print summary
    echo ""
    print_info "================================"
    print_info "Processing Summary:"
    print_info "  Total CUE files found: $total_count"
    print_info "  Successfully processed: $success_count"
    if [ $fail_count -gt 0 ]; then
        print_error "  Failed: $fail_count"
    fi
    print_info "================================"
}

# Main script
main() {
    print_info "CUE Sheet Audio Splitter"
    print_info "========================="
    echo ""

    # Check dependencies
    check_dependencies

    # Determine starting directory
    local start_dir="${1:-.}"

    if [ ! -d "$start_dir" ]; then
        print_error "Directory not found: $start_dir"
        exit 1
    fi

    # Process the directory tree
    process_directory "$start_dir"

    print_info "Processing complete!"
}

# Run main function
main "$@"
