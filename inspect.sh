#!/bin/bash
# Default to your repo's systemd unit if no argument is passed
TARGET=${1:-"llama-cpp.service"}

# Initialize an empty array to collect PIDs to process
PIDs=()

# 1. Determine if the target input is a PID or a Systemd Service
if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
    # It is a number, treat it as a single PID
    PIDs+=("$TARGET")
else
    # It is a string, treat it as a systemd service name and extract PIDs
    echo "Scanning systemd user unit [ $TARGET ] for active llama-servers..."
    SYSTEMD_PIDs=$(systemd-cgls --user "$TARGET" 2>/dev/null | grep -oP '^\s*[├└]─\s*\K\d+')
    
    if [ -z "$SYSTEMD_PIDs" ]; then
        echo "Error: No active PIDs found for unit '$TARGET'. Check systemctl --user status."
        exit 1
    fi
    
    # Filter the discovered PIDs to ensure they are actually llama-servers
    for p in $SYSTEMD_PIDs; do
        if ps -p "$p" -o args= 2>/dev/null | grep -q 'llama-server'; then
            PIDs+=("$p")
        fi
    done
    
    if [ ${#PIDs[@]} -eq 0 ]; then
        echo "Error: Found processes in '$TARGET', but none of them are running 'llama-server'."
        exit 1
    fi
    echo "Found ${#PIDs[@]} active llama-server processes. Starting inspection..."
fi

# 2. Loop through all identified PIDs and perform the inspection
for PID in "${PIDs[@]}"; do
    CMD_LINE=$(ps -p "$PID" -o args= 2>/dev/null)
    if [ -z "$CMD_LINE" ]; then
        echo "Error: Process ID $PID not found or has exited."
        continue
    fi

    # Extract Port and Alias
    PORT=$(echo "$CMD_LINE" | grep -oP -- '--port \s*\K\d+')
    if [ -z "$PORT" ]; then
	    continue
    fi
    ALIAS=$(echo "$CMD_LINE" | grep -oP -- '--alias \s*\K\S+')
    [ -z "$PORT" ] && PORT="8080" 
    [ -z "$ALIAS" ] && ALIAS="Unknown Model"

    echo "================================================================="
    echo "$ALIAS (PID: $PID | Port: $PORT)"

    # Extract Hardware Resource Tracking
    if [ -d "/proc/$PID" ]; then
        RSS_KB=$(grep -i VmRSS "/proc/$PID/status" | awk '{print $2}')
        VSZ_KB=$(grep -i VmSize "/proc/$PID/status" | awk '{print $2}')
        printf " -> Unified System RAM (RSS): %.2f GB\n" "$(echo "$RSS_KB / 1024 / 1024" | bc -l)"
        printf " -> Virtual Memory Footprint: %.2f GB\n" "$(echo "$VSZ_KB / 1024 / 1024" | bc -l)"
    fi

    # Query NVIDIA telemetry
    VRAM_MIB=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits 2>/dev/null | grep "^$PID," | cut -d',' -f2 | tr -d ' ')
    if [ ! -z "$VRAM_MIB" ]; then
        printf " -> Dedicated Blackwell VRAM: %.2f GB\n" "$(echo "$VRAM_MIB / 1024" | bc -l)"
    else
        echo " -> Dedicated Blackwell VRAM: [No active VRAM allocation detected]"
    fi

    # Pull Live State from the /slots API Endpoints
    SLOTS_JSON=$(curl -s "http://127.0.0.1:${PORT}/slots")

    if [ -z "$SLOTS_JSON" ]; then
        echo " -> Error: Could not pull live slots data. Verify endpoint is accessible."
        echo "================================================================="
        continue
    fi

    # Use JQ parsing if available, fallback to regex if not
    # echo "http://127.0.0.1:${PORT}/slots"
    if command -v jq &> /dev/null; then
        echo "$SLOTS_JSON" | jq -c '.[]' | while read -r slot; do
            ID=$(echo "$slot" | jq '.id')
            IS_PROCESSING=$(echo "$slot" | jq '.is_processing')
            PROMPT=$(echo "$slot" | jq '.n_prompt_tokens // 0')
            DECODED=$(echo "$slot" | jq '.next_token[0].n_decoded // 0') # Guarded nested index parsing
	    CTX=$(echo "$slot" | jq '.n_ctx // 0')

            if [ "$IS_PROCESSING" = "true" ]; then
                COLOR="\e[31m" 
                STATUS="PROCESSING"
            else
                COLOR="\e[32m" 
                STATUS="IDLE"
            fi
            echo -e " -> Slot [${ID}]: Status = ${COLOR}${STATUS}\e[0m | Context Ingested = ${PROMPT} tokens | Active Gen Tokens = ${DECODED} | n_ctx = ${CTX}"
        done
    else
        echo "$SLOTS_JSON" | sed 's/},{"/\n/g' | while read -r line; do
            ID=$(echo "$line" | grep -oP '"id":\K\d+')
            [ -z "$ID" ] && continue
            
            IS_PROCESSING=$(echo "$line" | grep -oP '"is_processing":\K[^,}]++')
            PROMPT=$(echo "$line" | grep -oP '"n_prompt_tokens":\K\d+' || echo "0")
            DECODED=$(echo "$line" | grep -oP '"n_decoded":\K\d+' || echo "0")
            
            if [ "$IS_PROCESSING" = "true" ]; then
                COLOR="\e[31m"
                STATUS="PROCESSING"
            else
                COLOR="\e[32m"
                STATUS="IDLE"
            fi
            echo -e " -> Slot [${ID}]: Status = ${COLOR}${STATUS}\e[0m | Context Ingested = ${PROMPT} tokens | Active Gen Tokens = ${DECODED}"
        done
    fi
    echo "================================================================="
    echo "" # Spacer between multiple process logs
done
free -mh
