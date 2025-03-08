#!/bin/bash

# ANSI color codes
RED='\033[91m'
GREEN='\033[92m'
GOLD='\033[93m'
RESET='\033[0m'

# ASCII art banner
echo -e "${GOLD}"
cat << "EOF"
  ____ ____  _____ _    _ __  __ 
 | __ ) ___|| ____| |  | |  \/  |
 |  _ \___ \|  _| | |  | | |\/| |
 | |_) |__) | |___| |__| | |  | |
 |____/____/|_____|\____/|_|  |_|
    HACKTIVIST INDONESIA 
EOF
echo -e "${RESET}"

# Required tools
REQUIRED_TOOLS=("gau" "uro" "httpx-toolkit" "nuclei")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}[ERROR] $tool is not installed. Please install it.${RESET}"
        exit 1
    fi
done

# Update script from GitHub
log "Checking for updates..."
git pull origin main &>/dev/null && log "Script updated successfully." || log "No updates available or GitHub repo not configured."

# Input domain or file
read -p "Enter the target domain or subdomains list file: " INPUT
[ -z "$INPUT" ] && { echo -e "${RED}[ERROR] Input cannot be empty.${RESET}"; exit 1; }

# Determine input type
if [ -f "$INPUT" ]; then
    TARGETS=$(cat "$INPUT")
else
    TARGETS="$INPUT"
fi
TARGETS=$(echo "$TARGETS" | sed 's|https\?://||g')

# Define output files
GAU_FILE=$(mktemp)
FILTERED_URLS_FILE="filtered_urls.txt"
NUCLEI_RESULTS="nuclei_results.txt"
LOG_FILE="scan.log"

# Logging function
log() { echo -e "$(date +%Y-%m-%dT%H:%M:%S) [INFO] $1" | tee -a "$LOG_FILE"; }

# Fetch URLs
echo "$TARGETS" | xargs -P10 -I{} sh -c 'gau "{}" >> "$1"' _ "$GAU_FILE"
log "Fetched URLs saved to $GAU_FILE"

# Filter URLs with query parameters
grep -E '\?[^=]+=.+$' "$GAU_FILE" | uro | sort -u > "$FILTERED_URLS_FILE"
log "Filtered URLs saved to $FILTERED_URLS_FILE"

# Check live URLs
httpx-toolkit -silent -t 300 -rl 200 < "$FILTERED_URLS_FILE" > "${FILTERED_URLS_FILE}.tmp"
mv "${FILTERED_URLS_FILE}.tmp" "$FILTERED_URLS_FILE"
log "Live URLs checked and updated."

# Run nuclei scan
nuclei -dast -retries 2 -silent -o "$NUCLEI_RESULTS" < "$FILTERED_URLS_FILE"
log "Nuclei scan completed. Results saved to $NUCLEI_RESULTS"

# Check results
if [ ! -s "$NUCLEI_RESULTS" ]; then
    log "No vulnerabilities found."
else
    log "Vulnerabilities detected! Check $NUCLEI_RESULTS"
fi

echo -e "${GREEN}[INFO] Scan completed. Check logs at $LOG_FILE${RESET}"
