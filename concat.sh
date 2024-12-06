#!/usr/bin/env bash

# Disable filename expansion by the shell so that *.sh is not expanded.
set -f

function set_colors() {
    RED='\033[1;31m'    # Bright Red
    GREEN='\033[1;32m'  # Bright Green
    YELLOW='\033[1;93m' # Light Yellow
    BLUE='\033[1;36m'   # Light Cyan
    MAGENTA='\033[1;35m' # Magenta
    NC='\033[0m'        # No Color (reset)
}

# Use colors if output is a terminal and no --no-color arg is passed
if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"; then
    set_colors
fi

# Default output file
default_output="concat.o"

# Function to display help
show_help() {
    echo -e "${BLUE}Usage:${NC} $0 [options] [pattern ...] [output_file]"
    echo ""
    echo -e "${BLUE}Description:${NC}"
    echo -e "  Concatenate files into a single output file."
    echo -e "  If no output file is specified, defaults to '${GREEN}${default_output}${NC}'."
    echo -e "  All arguments before the last one are treated as file patterns."
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  ${GREEN}-h${NC}             Show this help message and exit"
    echo -e "  ${GREEN}-i${NC}             Interactive mode: prompts per file to include or skip"
    echo -e "  ${GREEN}-d${NC}             Describe files before concatenation (optional)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${GREEN}concat *.c *.h out.txt${NC}    # Concatenate all .c and .h files into out.txt"
    echo -e "  ${GREEN}concat *.py${NC}               # Concatenate all .py files into the default output file"
    echo -e "  ${GREEN}concat -d *.sh script.out${NC} # Concatenate all .sh files with descriptions into script.out"
    echo -e "  ${GREEN}concat -i${NC}                 # Interactive mode to choose files from all matches"
}

# Default variables
patterns=()
interactive_mode=false
describe_mode=false

# Parse known options first
while getopts "hid" opt; do
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
        *)
            show_help
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

arg_count=$#
if [ $arg_count -eq 0 ]; then
    # No patterns, no output specified
    output_file="$default_output"
    patterns=() # means all files
    echo -e "${YELLOW}No patterns and no output file specified. Using all files -> $output_file${NC}"
elif [ $arg_count -eq 1 ]; then
    # Only one argument: treat as output file
    output_file="$1"
    patterns=() # means all files
    echo -e "${YELLOW}No patterns specified, using all files. Output: $output_file${NC}"
else
    # Multiple arguments: last one is output file, the rest are patterns
    output_file="${!arg_count}"
    arg_limit=$((arg_count - 1))
    for (( i=1; i<=arg_limit; i++ )); do
        patterns+=("${!i}")
    done
fi

output_file_abs=$(readlink -f "$output_file")

# If interactive mode and no patterns given, prompt for pattern or 'all'
if $interactive_mode && [ ${#patterns[@]} -eq 0 ]; then
    echo -e "${GREEN}Interactive mode enabled.${NC}"
    echo "Enter a file pattern (e.g., '*.c'), or type 'all' to select all files:"
    read -r user_input
    if [[ $user_input == "all" ]]; then
        patterns=() # empty means all files
    else
        patterns=("$user_input")
    fi
fi

# Determine file list
if [ ${#patterns[@]} -eq 0 ]; then
    # No patterns given: use all files
    file_list=$(find . -type f)
else
    # Use provided patterns
    file_list=""
    for p in "${patterns[@]}"; do
        matches=$(find . -type f -name "$p")
        file_list="$file_list"$'\n'"$matches"
    done
    # Remove leading empty lines if any
    file_list=$(echo "$file_list" | sed '/^\s*$/d')
fi

# If interactive mode is on, ask user for each file
selected_files=()
if $interactive_mode; then
    echo -e "${YELLOW}You will be prompted for each file to include (y/n).${NC}"
    IFS=$'\n'
    for file in $file_list; do
        [ -z "$file" ] && continue
        echo -en "${BLUE}Include ${file}? [y/n]: ${NC}"
        read -r answer
        if [[ $answer == [Yy] ]]; then
            selected_files+=("$file")
        fi
    done
    file_list=$(printf "%s\n" "${selected_files[@]}")
    IFS="$OLDIFS"
fi

# Clear output file
> "$output_file"

echo -e "${GREEN}Concatenating files into ${output_file}...${NC}"

echo "$file_list" | while read -r file; do
    [ -z "$file" ] && continue
    full_path=$(readlink -f "$file")

    # Skip the output file
    if [[ "$full_path" == "$output_file_abs" ]]; then
        continue
    fi
    
    echo -e "${YELLOW}Processing: $file${NC}"
    echo "--- START: $file ---" >> "$output_file"

    if $describe_mode; then
        # Add a description of the file before its contents
        file_size=$(wc -c < "$file")
        echo "Description: $file (size: $file_size bytes)" >> "$output_file"
    fi

    cat "$file" >> "$output_file"
    echo "" >> "$output_file"
done

echo "--- END PATH: $output_file_abs ---" >> "$output_file"
echo -e "${GREEN}Done.${NC}"
