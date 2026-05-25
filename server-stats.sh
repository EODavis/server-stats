#!/bin/bash
# ============================================================
#  server-stats.sh — Basic Server Performance Analyser
#  Author : Davis Immanuel (EODavis)
#  Purpose: Display key server performance stats at a glance
# ============================================================

# ---------- Colour Codes (for a cleaner terminal output) ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- Helper: Section Header ---------------------------
section() {
    echo ""
    echo -e "${CYAN}${BOLD}========================================${RESET}"
    echo -e "${CYAN}${BOLD}  $1${RESET}"
    echo -e "${CYAN}${BOLD}========================================${RESET}"
}

# ============================================================
# STRETCH GOAL STATS — OS, Uptime, Load, Users, Failed Logins
# ============================================================

section "SYSTEM OVERVIEW"

# OS Version
OS_NAME=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
echo -e "${BOLD}OS Version     :${RESET} ${OS_NAME:-Unknown}"

# Hostname
echo -e "${BOLD}Hostname       :${RESET} $(hostname)"

# Kernel
echo -e "${BOLD}Kernel         :${RESET} $(uname -r)"

# Uptime + Load Average
UPTIME_INFO=$(uptime -p 2>/dev/null || uptime)
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)
echo -e "${BOLD}Uptime         :${RESET} ${UPTIME_INFO}"
echo -e "${BOLD}Load Average   :${RESET} ${LOAD_AVG}  ${YELLOW}(1min, 5min, 15min)${RESET}"

# Logged-in Users
USER_COUNT=$(who | wc -l)
echo -e "${BOLD}Logged-in Users:${RESET} ${USER_COUNT}"
who | awk '{printf "  → %-10s %s %s\n", $1, $3, $4}' 2>/dev/null

# Failed Login Attempts (requires auth.log or secure)
section "FAILED LOGIN ATTEMPTS"
if [ -f /var/log/auth.log ]; then
    FAILED=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo 0)
    echo -e "${BOLD}Total Failed SSH Logins:${RESET} ${RED}${FAILED}${RESET}"
    echo -e "${YELLOW}Top offending IPs:${RESET}"
    grep "Failed password" /var/log/auth.log 2>/dev/null \
        | grep -oP '(\d+\.){3}\d+' \
        | sort | uniq -c | sort -rn \
        | head -5 \
        | awk '{printf "  %-6s attempts from %s\n", $1, $2}'
elif [ -f /var/log/secure ]; then
    FAILED=$(grep -c "Failed password" /var/log/secure 2>/dev/null || echo 0)
    echo -e "${BOLD}Total Failed SSH Logins:${RESET} ${RED}${FAILED}${RESET}"
else
    echo -e "${YELLOW}  Log file not accessible (try running as root/sudo)${RESET}"
fi

# ============================================================
# CORE REQUIREMENT 1 — CPU USAGE
# ============================================================

section "CPU USAGE"

# Total CPU usage = 100% - idle%
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%,')
# Fallback if awk captures different format
if [ -z "$CPU_IDLE" ]; then
    CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed 's/.*,\s*\([0-9.]*\)\s*id.*/\1/')
fi
CPU_USED=$(echo "100 - ${CPU_IDLE:-0}" | bc 2>/dev/null || echo "N/A")

echo -e "${BOLD}CPU Used       :${RESET} ${GREEN}${CPU_USED}%${RESET}"
echo -e "${BOLD}CPU Idle       :${RESET} ${CPU_IDLE}%"

# Per-core breakdown (optional, works on most Linux)
echo ""
echo -e "${YELLOW}Per-core snapshot:${RESET}"
top -bn1 | grep "^%Cpu" | awk '{printf "  Core: us=%-6s sy=%-6s id=%-6s\n", $2, $4, $8}'

# ============================================================
# CORE REQUIREMENT 2 — MEMORY USAGE
# ============================================================

section "MEMORY USAGE"

# Parse free output (values in MiB)
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m  | awk '/^Mem:/{print $3}')
MEM_FREE=$(free -m  | awk '/^Mem:/{print $4}')
MEM_PCT=$(awk "BEGIN {printf \"%.1f\", ($MEM_USED/$MEM_TOTAL)*100}")

echo -e "${BOLD}Total Memory   :${RESET} ${MEM_TOTAL} MiB"
echo -e "${BOLD}Used           :${RESET} ${RED}${MEM_USED} MiB  (${MEM_PCT}%)${RESET}"
echo -e "${BOLD}Free           :${RESET} ${GREEN}${MEM_FREE} MiB${RESET}"

# Swap
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED=$(free -m  | awk '/^Swap:/{print $3}')
SWAP_FREE=$(free -m  | awk '/^Swap:/{print $4}')
echo ""
echo -e "${YELLOW}Swap:${RESET}"
echo -e "  Total: ${SWAP_TOTAL} MiB  |  Used: ${SWAP_USED} MiB  |  Free: ${SWAP_FREE} MiB"

# ============================================================
# CORE REQUIREMENT 3 — DISK USAGE
# ============================================================

section "DISK USAGE"

echo -e "${BOLD}$(df -h | awk 'NR==1')${RESET}"
df -h | awk 'NR>1 && /^\// {
    pct = $5 + 0
    if (pct >= 90)      colour = "\033[0;31m"   # Red  — critical
    else if (pct >= 70) colour = "\033[1;33m"   # Yellow — warning
    else                colour = "\033[0;32m"   # Green — OK
    printf "  %s%-6s\033[0m  %s\n", colour, $5, $0
}'

echo ""
# Total across all mounted filesystems
df -h --total 2>/dev/null | awk '/total/{
    printf "TOTAL  →  Used: %-8s Free: %-8s  (%s used)\n", $3, $4, $5
}'

# ============================================================
# CORE REQUIREMENT 4 — TOP 5 PROCESSES BY CPU
# ============================================================

section "TOP 5 PROCESSES BY CPU USAGE"

printf "${BOLD}%-8s %-25s %6s %6s${RESET}\n" "PID" "COMMAND" "%CPU" "%MEM"
echo "----------------------------------------------------"
ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {
    cmd = substr($11, 1, 24)
    printf "%-8s %-25s %6s %6s\n", $2, cmd, $3, $4
}'

# ============================================================
# CORE REQUIREMENT 5 — TOP 5 PROCESSES BY MEMORY
# ============================================================

section "TOP 5 PROCESSES BY MEMORY USAGE"

printf "${BOLD}%-8s %-25s %6s %6s${RESET}\n" "PID" "COMMAND" "%MEM" "%CPU"
echo "----------------------------------------------------"
ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {
    cmd = substr($11, 1, 24)
    printf "%-8s %-25s %6s %6s\n", $2, cmd, $4, $3
}'

# ============================================================
# FOOTER
# ============================================================

echo ""
echo -e "${CYAN}${BOLD}========================================${RESET}"
echo -e "${CYAN}  Report generated: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo -e "${CYAN}${BOLD}========================================${RESET}"
echo ""
