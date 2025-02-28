#!/usr/bin/env bash

# Disable filename expansion by the shell so that patterns are not expanded.
set -f

# Save original IFS
OLDIFS=$IFS

function set_colors() {
    RED='\033[1;31m'    # Bright Red
    GREEN='\033[1;32m'  # Bright Green
    YELLOW='\033[1;33m' # Yellow
    BLUE='\033[1;34m'   # Blue
    MAGENTA='\033[1;35m' # Magenta
    NC='\033[0m'        # No Color (reset)
}
set_colors

# Function to display help
show_help() {
    echo -e "${BLUE}Usage:${NC} $0 [options] [pattern ...] [output_file]"
    echo ""
    echo -e "${BLUE}Description:${NC}"
    echo -e "  Concatenate files into a single output file."
    echo -e "  If no output file is specified, defaults to '${GREEN}concat.o${NC}'."
    echo -e "  All arguments before the last one are treated as file patterns."
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  ${GREEN}-h${NC}             Show this help message and exit"
    echo -e "  ${GREEN}-i${NC}             Interactive mode: prompts per file to include or skip"
    echo -e "  ${GREEN}-d${NC}             Describe files before concatenation"
    echo -e "  ${GREEN}-n${NC}             Disable colored output"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${GREEN}$0 *.c *.h out.txt${NC}    # Concatenate all .c and .h files into out.txt"
    echo -e "  ${GREEN}$0 *.py${NC}               # Concatenate all .py files into the default output file"
    echo -e "  ${GREEN}$0 -d *.sh script.out${NC} # Concatenate all .sh files with descriptions into script.out"
    echo -e "  ${GREEN}$0 -i${NC}                 # Interactive mode to choose files from all matches"
}

# Default variables
patterns=()
interactive_mode=false
describe_mode=false
no_color=false

# Parse options
while getopts "hidn" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        i)
            interactive_mode=true
            ;;
        d)
            describe_mode=true
            ;;
        n)
            no_color=true
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

# Determine output file and patterns
arg_count=$#
if [ $arg_count -eq 0 ]; then
    output_file="concat.o"
    patterns=()
elif [ $arg_count -eq 1 ]; then
    output_file="$1"
    patterns=()
else
    output_file="${!#}"
    patterns=( "${@:1:$((arg_count-1))}" )
fi

# Check if output file is a directory or already exists
if [ -e "$output_file" ]; then
    if [ -d "$output_file" ]; then
        echo -e "${RED}Error: Output file '$output_file' is a directory.${NC}"
    else
        echo -e "${RED}Error: Output file '$output_file' already exists.${NC}"
    fi
    exit 1
fi

# Create output directory if necessary
output_dir=$(dirname "$output_file")
if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir" || { echo -e "${RED}Error: Failed to create directory '$output_dir'.${NC}"; exit 1; }
fi

# Interactive mode: prompt for pattern if none provided
if $interactive_mode && [ ${#patterns[@]} -eq 0 ]; then
    echo -e "${GREEN}Interactive mode enabled.${NC}"
    echo "Enter a file pattern (e.g., '*.c'), or type 'all' to select all files:"
    read -r user_input
    if [[ "$user_input" == "all" ]]; then
        patterns=()
    else
        patterns=("$user_input")
    fi
fi

# Generate file list based on patterns
file_list=()
if [ ${#patterns[@]} -eq 0 ]; then
    # Include all files non-recursively
    while IFS= read -r -d $'\0' file; do
        file_list+=("$file")
    done < <(find . -maxdepth 1 -type f -print0)
else
    # Process each pattern
    for p in "${patterns[@]}"; do
        dir_part=$(dirname "$p")
        file_part=$(basename "$p")
        if [ ! -d "$dir_part" ]; then
            echo -e "${YELLOW}Warning: Directory '$dir_part' does not exist. Skipping pattern '$p'.${NC}"
            continue
        fi
        while IFS= read -r -d $'\0' file; do
            file_list+=("$file")
        done < <(find "$dir_part" -type f -name "$file_part" -print0 2>/dev/null)
    done
fi

# Remove duplicates
IFS=$'\n'
sorted_files=($(printf "%s\n" "${file_list[@]}" | sort -u))
IFS=$OLDIFS

# Check if any files were found
if [ ${#sorted_files[@]} -eq 0 ]; then
    echo -e "${RED}Error: No files found matching the specified patterns.${NC}"
    exit 1
fi

# Interactive mode: prompt for each file
selected_files=()
if $interactive_mode; then
    echo -e "${YELLOW}Interactive selection:${NC}"
    for file in "${sorted_files[@]}"; do
        echo -ne "${BLUE}Include ${file}? [y/n]: ${NC}"
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            selected_files+=("$file")
        fi
    done
    sorted_files=("${selected_files[@]}")
fi

# Check again in case all files were skipped
if [ ${#sorted_files[@]} -eq 0 ]; then
    echo -e "${YELLOW}No files selected. Exiting.${NC}"
    exit 0
fi

# Concatenate files
output_file_abs=$(readlink -f "$output_file")
echo -e "${GREEN}Concatenating ${#sorted_files[@]} files into '$output_file'...${NC}"
echo "" > "$output_file"

for file in "${sorted_files[@]}"; do
    full_path=$(readlink -f "$file")
    if [[ "$full_path" == "$output_file_abs" ]]; then
        echo -e "${YELLOW}Skipping output file: $file${NC}"
        continue
    fi
    if [ ! -r "$file" ]; then
        echo -e "${RED}Error: Cannot read file '$file'. Skipping.${NC}"
        continue
    fi
    echo -e "${YELLOW}Processing: $file${NC}"
    echo "--- START: $file ---" >> "$output_file"
    if $describe_mode; then
        file_size=$(wc -c < "$file")
        echo "Description: $file (size: $file_size bytes)" >> "$output_file"
    fi
    cat "$file" >> "$output_file"
    echo "" >> "$output_file"
done

echo "--- END ---" >> "$output_file"
echo -e "${GREEN}Done. Output saved to '$output_file'.${NC}"
