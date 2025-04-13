#!/bin/bash

# === Colors ===
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

# === ASCII Banner ===
echo -e "${YELLOW}"
cat << "EOF"
                                            █████  ███                                               
                                           ░░███  ░░░                                                
  ██████  ████████   ██████  ████████    ███████  ████  ████████  █████████████    ██████  ████████  
 ███░░███░░███░░███ ███░░███░░███░░███  ███░░███ ░░███ ░░███░░███░░███░░███░░███  ███░░███░░███░░███ 
░███ ░███ ░███ ░███░███████  ░███ ░███ ░███ ░███  ░███  ░███ ░░░  ░███ ░███ ░███ ░███ ░███ ░███ ░███ 
░███ ░███ ░███ ░███░███░░░   ░███ ░███ ░███ ░███  ░███  ░███      ░███ ░███ ░███ ░███ ░███ ░███ ░███ 
░░██████  ░███████ ░░██████  ████ █████░░████████ █████ █████     █████░███ █████░░██████  ████ █████
 ░░░░░░   ░███░░░   ░░░░░░  ░░░░ ░░░░░  ░░░░░░░░ ░░░░░ ░░░░░     ░░░░░ ░░░ ░░░░░  ░░░░░░  ░░░░ ░░░░░ 
          ░███                                                                                       
          █████                                                                                      
         ░░░░░                                                                                       
EOF
echo -e "${NC}"

# Usage:
#   ./monitor_open_directory.sh <URL> [interval_seconds] [wget_options]

set -e

# === Args ===
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <URL> [interval_seconds] [wget_options]${NC}"
    exit 1
fi

URL="$1"
INTERVAL="${2:-300}"  # Default to 300 seconds (5 minutes) if no interval is provided
shift 2  # Shift positional arguments to access additional wget options
USER_WGET_OPTS=("$@")  # Capture remaining arguments as wget options

# === Audit and Hash Log ===
BASE_DIR=~/opendirmon
DOWNLOADS_DIR="$BASE_DIR/downloads"
HASH_DIR="$BASE_DIR/opendir"
HASH_FILE="$HASH_DIR/hashes.txt"
IP_LOG="$HASH_DIR/ip_log.txt"
mkdir -p "$HASH_DIR" "$DOWNLOADS_DIR"
touch "$HASH_FILE"
touch "$IP_LOG"

# === Load known hashes ===
declare -A seen_hashes
while IFS= read -r line; do
    HASH=$(echo "$line" | awk '{print $1}')
    seen_hashes["$HASH"]=1
done < "$HASH_FILE"

# === Clean hostname for download dir ===
HOSTNAME=$(echo "$URL" | awk -F/ '{print $3}' | sed 's/:/_/g')

# === List of User-Agents ===
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/91.0.864.48 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/89.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:2.0) Gecko/20100101 Firefox/4.0"
    "curl/7.68.0"
    "Python/3.8.5"
    "Mozilla/5.0 (Linux; Android 10; Pixel 4 XL) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36"
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (iPad; CPU OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:91.0) Gecko/20100101 Firefox/91.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36"
    "Mozilla/5.0 (Linux; Android 10; Pixel 3a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36"
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
    "Mozilla/5.0 (compatible; Bingbot/2.0; +http://www.bing.com/bingbot.htm)"
    "PowerShell/7.1.3"
    "Wget/1.21.1"
    "PostmanRuntime/7.28.4"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    "Mozilla/5.0 (Linux; Android 12; Pixel 6 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0"
    "Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)"
    "Mozilla/5.0 (compatible; DuckDuckBot/1.0; +http://duckduckgo.com/duckduckbot.html)"
    "Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)"
    "Mozilla/5.0 (Linux; U; Android 9; en-US; SM-G960U Build/PPR1.180610.011) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/70.0.3538.80 Mobile Safari/537.36"
    "Mozilla/5.0 (compatible; MJ12bot/v1.4.8; http://mj12bot.com/)"
    "Mozilla/5.0 (compatible; AhrefsBot/7.0; +http://ahrefs.com/robot/)"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.10 Safari/605.1.1"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.3"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.3"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.3"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Trailer/93.3.8652.5"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0."
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0."
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36 OPR/117.0.0."
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36 Edg/132.0.0."
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36 Edge/18.1958"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136."
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.3"
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.3"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3.1 Mobile/15E148 Safari/604."
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) GSA/360.1.737798518 Mobile/15E148 Safari/604."
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/134.0.6998.99 Mobile/15E148 Safari/604."
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/27.0 Chrome/125.0.0.0 Mobile Safari/537.3"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604."
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604."
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1.1 Mobile/15E148 Safari/604."
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.3"
    "Mozilla/5.0 (Android 14; Mobile; rv:136.0) Gecko/136.0 Firefox/136."
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.3"
    "Mozilla/5.0 (Linux; Android 10; JNY-LX1; HMSCore 6.15.0.302) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.5735.196 HuaweiBrowser/15.0.4.312 Mobile Safari/537.3"
    "Mozilla/5.0 (Android 15; Mobile; rv:136.0) Gecko/136.0 Firefox/136."
    "Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) CriOS/56.0.2924.75 Mobile/14E5239e YisouSpider/5.0 Safari/602."
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604."
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.3"
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.3"
)

# === Wget Options ===
DEFAULT_WGET_OPTS=(
    --recursive
    --no-parent
    --no-host-directories
    --reject "index.html*"
    --no-check-certificate
    --quiet
    --timeout=15
    --tries=1  # Ensure wget does not retry indefinitely
    --cut-dirs=1  # Default cut-dirs
    --quota=150m  # Default quota
)

# Combine default options with user-specified options
WGET_OPTS=("${DEFAULT_WGET_OPTS[@]}")

# Override defaults if specified by the user
for opt in "${USER_WGET_OPTS[@]}"; do
    key=$(echo "$opt" | cut -d= -f1)
    found=false
    for existing_opt in "${WGET_OPTS[@]}"; do
        if [[ "$existing_opt" == "$key="* ]]; then
            found=true
            break
        fi
    done
    if $found; then
        echo -e "${YELLOW}[!] Overriding default wget option: $key${NC}"
        WGET_OPTS=("${WGET_OPTS[@]/$key=*/}" "$opt")
    else
        WGET_OPTS+=("$opt")
    fi
done

# === Obtain Actual Public IP Address ===
echo -e "${YELLOW}[*] Ensuring PIA VPN is not running to obtain actual public IP address...${NC}"
piactl disconnect || echo -e "${YELLOW}[!] PIA VPN was not connected.${NC}"
sleep 5  # Allow time for disconnection

ACTUAL_PUBLIC_IP=$(curl -s http://ifconfig.me/ip || echo "Unknown")
if [[ "$ACTUAL_PUBLIC_IP" == "Unknown" ]]; then
    echo -e "${RED}[!] Unable to determine actual public IP address. Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Actual public IP address: $ACTUAL_PUBLIC_IP${NC}"

# === Function to Check VPN Status ===
check_vpn_status() {
    VPN_STATE=$(piactl get connectionstate)
    VPN_IP=$(piactl get vpnip)
    echo -e "${YELLOW}[*] VPN Status: $VPN_STATE${NC}"
    if [[ "$VPN_STATE" == "Connected" ]]; then
        echo -e "${GREEN}[+] VPN is connected. VPN IP: $VPN_IP${NC}"
    else
        echo -e "${RED}[!] WARNING: VPN is not connected.${NC}"
    fi
}

# === Trap to Handle Script Exit ===
trap 'echo -e "${YELLOW}[*] Script exiting. Checking VPN status...${NC}"; check_vpn_status' EXIT

# === Rotate PIA and verify tunnel ===
rotate_and_verify_vpn() {
    echo -e "${YELLOW}[*] Rotating PIA VPN...${NC}"

    # Correct list of PIA regions
    AVAILABLE_REGIONS=(
        "us-chicago" "us-indiana" "us-iowa" "us-michigan" "us-missouri" "us-ohio" "us-wisconsin"
        "us-new-mexico" "us-maine" "us-nebraska" "us-pennsylvania" "us-new-hampshire" "us-east"
        "us-minnesota" "us-north-dakota" "us-vermont" "us-oregon" "us-washington-dc" "us-wyoming"
        "us-wilmington" "us-mississippi" "us-south-dakota" "us-rhode-island" "us-alabama" "us-atlanta"
        "us-idaho" "us-louisiana" "us-baltimore" "us-east-streaming-optimized" "us-massachusetts"
        "us-new-york" "us-tennessee" "us-kentucky" "us-virginia" "us-connecticut" "us-arkansas"
        "us-montana" "us-south-carolina" "us-oklahoma" "us-west-streaming-optimized" "us-alaska"
        "us-denver" "us-texas" "us-west-virginia" "us-north-carolina" "us-houston" "us-west"
        "us-kansas" "us-silicon-valley" "us-seattle" "us-california" "us-florida" "us-las-vegas"
        "us-salt-lake-city" "us-honolulu" "ca-montreal" "ca-toronto" "ca-ontario-streaming-optimized"
        "ca-ontario" "ca-vancouver" "venezuela" "greenland" "peru" "uruguay" "ecuador" "bahamas"
        "chile" "guatemala" "brazil" "bolivia" "argentina" "mexico" "costa-rica" "panama"
        "uk-streaming-optimized" "uk-london" "uk-southampton" "uk-manchester" "dk-streaming-optimized"
        "dk-copenhagen" "andorra" "colombia" "czech-republic" "bosnia-and-herzegovina" "estonia"
        "nl-netherlands-streaming-optimized" "netherlands" "norway" "algeria" "liechtenstein"
        "es-madrid" "es-valencia" "nigeria" "fi-helsinki" "fi-streaming-optimized" "isle-of-man"
        "poland" "it-streaming-optimized" "it-milano" "de-berlin" "de-germany-streaming-optimized"
        "de-frankfurt" "austria" "hungary" "se-streaming-optimized" "se-stockholm" "malta" "latvia"
        "morocco" "portugal" "slovenia" "monaco" "armenia" "lithuania" "ireland" "kazakhstan"
        "luxembourg" "croatia" "serbia" "moldova" "north-macedonia" "france" "georgia" "albania"
        "slovakia" "ukraine" "belgium" "iceland" "israel" "montenegro" "taiwan" "romania" "egypt"
        "bulgaria" "jp-tokyo" "jp-streaming-optimized" "greece" "cyprus" "switzerland" "turkey"
        "mongolia" "australia-streaming-optimized" "au-sydney" "au-melbourne" "au-adelaide"
        "au-brisbane" "au-perth" "new-zealand" "bangladesh" "china" "south-korea" "vietnam"
        "cambodia" "malaysia" "macao" "nepal" "sri-lanka" "united-arab-emirates" "india" "singapore"
        "hong-kong" "south-africa" "indonesia" "philippines" "qatar" "saudi-arabia"
    )

    declare -A region_failures  # Track failures per region

    while [[ ${#AVAILABLE_REGIONS[@]} -gt 0 ]]; do
        # Randomly select a region
        SELECTED_REGION="${AVAILABLE_REGIONS[$RANDOM % ${#AVAILABLE_REGIONS[@]}]}"
        echo -e "${YELLOW}[*] Connecting to PIA region: $SELECTED_REGION${NC}"

        for attempt in {1..5}; do
            piactl disconnect
            sleep 2
            piactl set region "$SELECTED_REGION"
            piactl connect

            # Timeout mechanism for VPN connection
            VPN_TIMEOUT=30  # Maximum time to wait for VPN to connect (in seconds)
            WAITED=0
            while [[ "$(piactl get connectionstate)" != "Connected" ]]; do
                echo -e "${YELLOW}[!] Waiting for PIA to connect...${NC}"
                sleep 2
                WAITED=$((WAITED + 2))
                if [[ $WAITED -ge $VPN_TIMEOUT ]]; then
                    echo -e "${RED}[!] VPN connection timed out after $VPN_TIMEOUT seconds.${NC}"
                    break
                fi
            done

            if [[ "$(piactl get connectionstate)" == "Connected" ]]; then
                VPN_IP=$(piactl get vpnip)
                CURRENT_PUBLIC_IP=$(curl -s -w "%{http_code}" -o /tmp/current_ip.txt http://ifconfig.me/ip)
                HTTP_STATUS=${CURRENT_PUBLIC_IP: -3}  # Extract HTTP status code
                CURRENT_PUBLIC_IP=$(cat /tmp/current_ip.txt || echo "Unknown")

                TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
                echo "$TIMESTAMP | VPN_IP=$VPN_IP | Public_IP=$CURRENT_PUBLIC_IP | Region=$SELECTED_REGION" >> "$IP_LOG"

                # Handle ifconfig.me returning 403
                if [[ "$HTTP_STATUS" == "403" ]]; then
                    echo -e "${RED}[!] ifconfig.me returned 403. Falling back to piactl IP.${NC}"
                    if [[ "$VPN_IP" != "$ACTUAL_PUBLIC_IP" && "$VPN_IP" != "Unknown" ]]; then
                        EFFECTIVE_IP=$VPN_IP
                    else
                        echo -e "${RED}[!] Both ifconfig.me and piactl failed to provide a valid VPN IP. Skipping region: $SELECTED_REGION.${NC}"
                        AVAILABLE_REGIONS=("${AVAILABLE_REGIONS[@]/$SELECTED_REGION}")
                        continue
                    fi
                else
                    # Select the valid IP for display
                    if [[ "$VPN_IP" != "Unknown" && -n "$VPN_IP" ]]; then
                        EFFECTIVE_IP=$VPN_IP
                    elif [[ "$CURRENT_PUBLIC_IP" != "Unknown" && -n "$CURRENT_PUBLIC_IP" ]]; then
                        EFFECTIVE_IP=$CURRENT_PUBLIC_IP
                    else
                        echo -e "${RED}[!] Both VPN_IP and CURRENT_PUBLIC_IP are invalid. Skipping region: $SELECTED_REGION.${NC}"
                        AVAILABLE_REGIONS=("${AVAILABLE_REGIONS[@]/$SELECTED_REGION}")
                        continue
                    fi
                fi

                if [[ "$EFFECTIVE_IP" != "$ACTUAL_PUBLIC_IP" && -n "$EFFECTIVE_IP" ]]; then
                    echo -e "${GREEN}[+] VPN active: $EFFECTIVE_IP (Region: $SELECTED_REGION)${NC}"
                    return 0
                else
                    echo -e "${RED}[!] WARNING: VPN IP mismatch or public IP matches actual public IP! VPN_IP=${VPN_IP}, CURRENT_PUBLIC_IP=${CURRENT_PUBLIC_IP}${NC}"
                fi
            fi

            echo -e "${RED}[!] Attempt $attempt to connect to $SELECTED_REGION failed.${NC}"
        done

        # Increment failure count for the region
        region_failures["$SELECTED_REGION"]=$((region_failures["$SELECTED_REGION"] + 1))
        echo -e "${RED}[!] Failed to connect to $SELECTED_REGION after 5 attempts.${NC}"

        # Remove region if it fails more than 3 times
        if [[ ${region_failures["$SELECTED_REGION"]} -gt 3 ]]; then
            echo -e "${RED}[!] Removing $SELECTED_REGION from available regions due to repeated failures.${NC}"
            AVAILABLE_REGIONS=("${AVAILABLE_REGIONS[@]/$SELECTED_REGION}")
        fi
    done

    echo -e "${RED}[!] All regions failed. Exiting.${NC}"
    exit 1
}

# === Check for Static User-Agent ===
STATIC_USER_AGENT=""
for opt in "${USER_WGET_OPTS[@]}"; do
    if [[ "$opt" == --user-agent=* ]]; then
        STATIC_USER_AGENT="true"
        echo -e "${YELLOW}[*] Static user agent detected in override arguments: ${opt#--user-agent=}.${NC}"
        break
    fi
done

# === Main Loop ===
echo -e "${YELLOW}[*] Monitoring $URL every $INTERVAL seconds (with jitter). Ctrl+C to stop.${NC}"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    TAG=$(date +%Y%m%d_%H%M%S)
    SOURCE_DIR="$DOWNLOADS_DIR/${HOSTNAME}_${TAG}"
    mkdir -p "$SOURCE_DIR"

    if rotate_and_verify_vpn; then
        # Use static user agent if defined, otherwise rotate user agents
        if [[ -z "$STATIC_USER_AGENT" ]]; then
            USER_AGENT="${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}"
            WGET_OPTS+=("--user-agent=$USER_AGENT")
            echo -e "${YELLOW}[$TIMESTAMP] Using random user agent: $USER_AGENT${NC}"
        else
            echo -e "${YELLOW}[$TIMESTAMP] Using static user agent from override arguments.${NC}"
        fi

        echo -e "${YELLOW}[$TIMESTAMP] Proceeding with download...${NC}"

        if wget --directory-prefix="$SOURCE_DIR" "${WGET_OPTS[@]}" "$URL"; then
            echo -e "${YELLOW}[$TIMESTAMP] Download succeeded. Processing files...${NC}"

            # Log user agent and IP used
            echo "$TIMESTAMP | WGET_OPTS=${WGET_OPTS[*]} | VPN_IP=$VPN_IP | Public_IP=$ACTUAL_IP" >> "$IP_LOG"

            NEW_FILES=false  # Flag to track if new files were found

            find "$SOURCE_DIR" -type f | while read -r FILE; do
                RELATIVE="${FILE#$SOURCE_DIR/}"
                echo -e "${YELLOW}[$TIMESTAMP] Observed: $RELATIVE${NC}"

                HASH=$(sha256sum "$FILE" | awk '{print $1}')

                if [[ -n "${seen_hashes[$HASH]}" ]]; then
                    # Log duplicates in red and delete file
                    echo -e "${RED}[$TIMESTAMP] Duplicate file observed: $RELATIVE${NC}"
                    rm -f "$FILE"
                else
                    seen_hashes["$HASH"]=1
                    echo "$HASH $TIMESTAMP" >> "$HASH_FILE"
                    echo -e "${GREEN}[+] New file: $RELATIVE${NC}"
                    NEW_FILES=true
                fi
            done

            # Remove the source directory if no new files were found
            if ! $NEW_FILES; then
                echo -e "${RED}[$TIMESTAMP] No new files found, removing $SOURCE_DIR.${NC}"
                rm -rf "$SOURCE_DIR"
            fi
        else
            echo -e "${RED}[$TIMESTAMP] ERROR: Download failed from $URL. Cleaning up...${NC}"
            rm -rf "$SOURCE_DIR" 2>/dev/null || true
        fi
    else
        echo -e "${RED}[$TIMESTAMP] Skipped: VPN tunnel not verified. Will retry.${NC}"
        rm -rf "$SOURCE_DIR" 2>/dev/null || true
    fi

    # Ensure empty directories are removed
    find "$DOWNLOADS_DIR" -type d -empty -delete

    # Fix divide-by-zero error in jitter calculation
    if (( INTERVAL > 10 )); then
        JITTER=$((RANDOM % (INTERVAL / 10)))
    else
        JITTER=0
    fi
    SLEEP_TIME=$((INTERVAL + JITTER - INTERVAL / 20))
    echo -e "${YELLOW}[$TIMESTAMP] Loop complete. Sleeping for $SLEEP_TIME seconds...${NC}"
    
    sleep "$SLEEP_TIME"
done
