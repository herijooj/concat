#!/usr/bin/env bash

function set_colors() {
    RED='\033[1;31m'        # Vermelho brilhante
    GREEN='\033[1;32m'      # Verde brilhante
    YELLOW='\033[1;93m'     # Amarelo claro
    BLUE='\033[1;36m'       # Azul claro ciano
    NC='\033[0m'            # Sem cor (reset)
}

# Configuração de cores para terminal
if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"; then
    set_colors
fi

# Function to display help
show_help() {
    echo -e "${BLUE}Usage:${NC} $0 ${YELLOW}[options]${NC} ${GREEN}[output_file]${NC}"
    echo ""
    echo -e "${BLUE}Concatenate files into a single output file with flexible selection.${NC}"
    echo -e "${BLUE}Default output file:${NC} concat.o"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "${GREEN}  -h${NC}             Show this help message and exit"
    echo -e "${GREEN}  -e${NC} ${YELLOW}pattern${NC}     Add a file pattern to match. ${RED}IMPORTANT: Quote the pattern!${NC}"
    echo -e "                 For example: ${YELLOW}-e \"*.c\"${NC} or ${YELLOW}-e \"*.sh\"${NC}"
    echo -e "${GREEN}  -i${NC}             Interactive mode: prompts you to choose patterns or 'all'"
    echo -e "${GREEN}  -d${NC}             Describe files before concatenation (customizable)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${GREEN}/src/${NC} output.txt                   # Concatenate all files"
    echo -e "  ${GREEN}/src/${NC} ${YELLOW}-e \"*.c\"${NC} output.txt          # Concatenate all .c files (quoted!)"
    echo -e "  ${GREEN}/src/${NC} ${YELLOW}-e \"*.c\" -e \"*.h\"${NC} output.txt # Concatenate all .c and .h files"
    echo -e "  ${GREEN}/src/${NC} ${YELLOW}-i${NC} output.txt                # Interactive mode"
    echo -e "  ${GREEN}/src/${NC} ${YELLOW}-d -e \"*.py\"${NC} output.txt      # Concatenate all .py files with descriptions"
}

# Default variables
declare -a patterns=()
interactive_mode=false
describe_mode=false
default_output="concat.o"

# Parse options
while getopts "he:id" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        e)
            # Add pattern exactly as provided. The user should quote patterns
            patterns+=("$OPTARG")
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

# Check if output file name is provided, otherwise use default
if [[ -z "$1" ]]; then
    output_file="$default_output"
    echo -e "${YELLOW}No output file specified. Using default: $output_file${NC}"
else
    output_file="$1"
fi

output_file_abs=$(readlink -f "$output_file")

# Interactive mode: prompt user if no patterns are provided
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
    # No patterns: use all files
    file_list=$(find . -type f)
else
    # Use provided patterns
    file_list=""
    for p in "${patterns[@]}"; do
        # Using the pattern as a literal string to find files
        matches=$(find . -type f -name "$p")
        file_list="$file_list"$'\n'"$matches"
    done
    # Remove leading empty lines if any
    file_list=$(echo "$file_list" | sed '/^\s*$/d')
fi

# Clear output file
> "$output_file"

echo -e "${GREEN}Concatenating files into $output_file...${NC}"

# Iterate through files
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
        # Add a description of the file before its contents, if desired
        file_size=$(wc -c < "$file")
        echo "Description: $file (size: $file_size bytes)" >> "$output_file"
    fi

    cat "$file" >> "$output_file"
    echo "" >> "$output_file"
done

# Add end path for the last file
echo "--- END PATH: $output_file_abs ---" >> "$output_file"

echo -e "${GREEN}Done.${NC}"

