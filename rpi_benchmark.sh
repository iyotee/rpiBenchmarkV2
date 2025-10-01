#!/bin/bash

# =====================================================
# RPi Benchmark v2.1 - Robust benchmarking script
# =====================================================

set -e

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.1"
readonly RESULTS_DIR="benchmark_results"
readonly DB_FILE="${RESULTS_DIR}/benchmarks.db"
readonly LOG_FILE="${RESULTS_DIR}/benchmark_$(date +%Y%m%d_%H%M%S).log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# === REFERENCE VALUES (Raspberry Pi 4 4GB) ===
declare -A REFERENCE_SCORES=(
    [cpu_single]=2000      # ops/sec
    [cpu_multi]=8000       # total ops
    [memory]=1500          # MB/s
    [disk_read]=40         # MB/s
    [disk_write]=35        # MB/s
    [network_down]=100     # Mbps
    [network_up]=50        # Mbps
)

# === DATA STRUCTURE ===
declare -A BENCHMARK_RESULTS=(
    [cpu_single]=0
    [cpu_multi]=0
    [memory]=0
    [disk_read]=0
    [disk_write]=0
    [network_down]=0
    [network_up]=0
    [network_ping]=0
)

# === PLATFORM DETECTION ===
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /proc/device-tree/model ]] && grep -q "Raspberry Pi" /proc/device-tree/model; then
        echo "raspbian"
    elif command -v vcgencmd &> /dev/null; then
        echo "raspbian"
    elif [[ -f /etc/os-release ]]; then
        # Use a different variable name to avoid conflict with readonly VERSION
        local os_id
        os_id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        if [[ "$os_id" =~ (debian|ubuntu|raspbian) ]]; then
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

readonly PLATFORM=$(detect_platform)

# === UTILITY FUNCTIONS ===

log_message() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() { log_message "INFO" "$@"; }
log_warn() { log_message "WARN" "$@"; }
log_error() { log_message "ERROR" "$@"; }

show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    printf "\r[${GREEN}"
    printf "%${filled}s" | tr ' ' '█'
    printf "${NC}"
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" $percent
}

validate_number() {
    local value=$1
    if [[ $value =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$value"
    else
        echo "0"
    fi
}

# === INITIALIZATION ===

init_environment() {
    mkdir -p "$RESULTS_DIR"
    
    # Check privileges
    if [[ "$PLATFORM" != "macos" ]] && [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges on Linux"
        exit 1
    fi
    
    log_info "Initializing environment..."
    log_info "Platform detected: $PLATFORM"
}

init_database() {
    if ! command -v sqlite3 &> /dev/null; then
        log_warn "SQLite3 not installed, installing..."
        install_package sqlite3
        
        # Check if sqlite3 is now available
        if ! command -v sqlite3 &> /dev/null; then
            log_error "Failed to install sqlite3. Please install it manually:"
            log_error "  Debian/Ubuntu: sudo apt-get install sqlite3"
            log_error "  CentOS/RHEL: sudo yum install sqlite"
            log_error "  macOS: brew install sqlite"
            exit 1
        fi
    fi
    
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS benchmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    cpu_single REAL,
    cpu_multi REAL,
    memory REAL,
    disk_read REAL,
    disk_write REAL,
    network_down REAL,
    network_up REAL,
    network_ping REAL,
    overall_score INTEGER,
    platform TEXT
);

CREATE TABLE IF NOT EXISTS system_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    benchmark_id INTEGER,
    cpu_model TEXT,
    cpu_cores INTEGER,
    ram_total INTEGER,
    disk_total INTEGER,
    FOREIGN KEY (benchmark_id) REFERENCES benchmarks(id)
);
EOF
    
    log_info "Database initialized"
}

install_package() {
    local package=$1
    log_info "Installing $package..."
    
    case $PLATFORM in
        macos)
            brew install "$package" 2>&1 | tee -a "$LOG_FILE"
            ;;
        raspbian|linux)
            apt-get update -qq && apt-get install -y "$package" 2>&1 | tee -a "$LOG_FILE"
            ;;
    esac
}

check_dependencies() {
    local deps=(sysbench bc curl)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "Missing dependencies: ${missing[*]}"
        for pkg in "${missing[@]}"; do
            install_package "$pkg"
        done
    fi
}

# === BENCHMARKS ===

benchmark_cpu_single() {
    log_info "${CYAN}Benchmark CPU Single-Thread${NC}"
    
    local temp_file=$(mktemp)
    sysbench cpu --cpu-max-prime=20000 --threads=1 run > "$temp_file" 2>&1
    
    local ops=$(grep "events per second:" "$temp_file" | awk '{print $NF}')
    ops=$(validate_number "$ops")
    
    rm "$temp_file"
    
    BENCHMARK_RESULTS[cpu_single]=$ops
    log_info "Result: ${ops} ops/sec"
    
    echo "$ops"
}

benchmark_cpu_multi() {
    log_info "${CYAN}Benchmark CPU Multi-Thread${NC}"
    
    local cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu)
    local temp_file=$(mktemp)
    
    sysbench cpu --cpu-max-prime=20000 --threads="$cores" run > "$temp_file" 2>&1
    
    local events=$(grep "total number of events:" "$temp_file" | awk '{print $NF}')
    events=$(validate_number "$events")
    
    rm "$temp_file"
    
    BENCHMARK_RESULTS[cpu_multi]=$events
    log_info "Result: ${events} events (${cores} threads)"
    
    echo "$events"
}

benchmark_memory() {
    log_info "${MAGENTA}Benchmark Mémoire${NC}"
    
    local temp_file=$(mktemp)
    sysbench memory --memory-block-size=1K --memory-total-size=10G run > "$temp_file" 2>&1
    
    local speed=$(grep "transferred" "$temp_file" | grep -oP '\d+\.\d+' | head -1)
    speed=$(validate_number "$speed")
    
    rm "$temp_file"
    
    BENCHMARK_RESULTS[memory]=$speed
    log_info "Result: ${speed} MB/s"
    
    echo "$speed"
}

benchmark_disk() {
    log_info "${YELLOW}Benchmark Disque${NC}"
    
    local test_file="/tmp/benchmark_disk_test"
    local size_mb=1000
    
    # Write test
    log_info "Write test..."
    local start=$(date +%s.%N)
    dd if=/dev/zero of="$test_file" bs=1M count=$size_mb conv=fdatasync 2>/dev/null
    local end=$(date +%s.%N)
    local write_speed=$(echo "scale=2; $size_mb / ($end - $start)" | bc)
    
    # Read test
    log_info "Read test..."
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    start=$(date +%s.%N)
    dd if="$test_file" of=/dev/null bs=1M 2>/dev/null
    end=$(date +%s.%N)
    local read_speed=$(echo "scale=2; $size_mb / ($end - $start)" | bc)
    
    rm -f "$test_file"
    
    write_speed=$(validate_number "$write_speed")
    read_speed=$(validate_number "$read_speed")
    
    BENCHMARK_RESULTS[disk_write]=$write_speed
    BENCHMARK_RESULTS[disk_read]=$read_speed
    
    log_info "Write: ${write_speed} MB/s | Read: ${read_speed} MB/s"
    
    echo "$write_speed $read_speed"
}

benchmark_network() {
    log_info "${BLUE}Benchmark Réseau${NC}"
    
    # Test ping
    local ping_result=$(ping -c 5 8.8.8.8 2>/dev/null | grep "avg" | cut -d'/' -f5)
    ping_result=$(validate_number "$ping_result")
    
    BENCHMARK_RESULTS[network_ping]=$ping_result
    
    # Speed test (if speedtest-cli available)
    if command -v speedtest-cli &> /dev/null; then
        local speedtest=$(speedtest-cli --simple 2>/dev/null)
        local download=$(echo "$speedtest" | grep "Download" | awk '{print $2}')
        local upload=$(echo "$speedtest" | grep "Upload" | awk '{print $2}')
        
        download=$(validate_number "$download")
        upload=$(validate_number "$upload")
        
        BENCHMARK_RESULTS[network_down]=$download
        BENCHMARK_RESULTS[network_up]=$upload
        
        log_info "Download: ${download} Mbps | Upload: ${upload} Mbps | Ping: ${ping_result} ms"
    else
        log_warn "speedtest-cli not available, speed tests ignored"
        BENCHMARK_RESULTS[network_down]=0
        BENCHMARK_RESULTS[network_up]=0
    fi
    
    echo "$ping_result"
}

# === SCORING SYSTEM ===

calculate_score() {
    local category=$1
    local value=$2
    local reference=${REFERENCE_SCORES[$category]}
    
    if [[ -z "$reference" ]] || [[ "$reference" == "0" ]]; then
        echo "0"
        return
    fi
    
    local score=$(echo "scale=0; ($value * 100) / $reference" | bc)
    echo "$score"
}

calculate_overall_score() {
    local total=0
    local count=0
    
    for category in cpu_single cpu_multi memory disk_read disk_write network_down network_up; do
        local value=${BENCHMARK_RESULTS[$category]}
        if [[ "$value" != "0" ]]; then
            local score=$(calculate_score "$category" "$value")
            total=$((total + score))
            count=$((count + 1))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "0"
    else
        echo $((total / count))
    fi
}

# === FEATURE 1: REAL-TIME TEMPERATURE MONITORING ===

get_cpu_temp() {
    # Method 0: Quick WSL check first
    if grep -q Microsoft /proc/version 2>/dev/null || [[ -n "$WSL_DISTRO_NAME" ]] || [[ -n "$WSLENV" ]]; then
        # WSL detected - try multiple approaches
        
        # Try wmic first
        if command -v wmic &> /dev/null; then
            local temp=$(wmic /namespace:\\\\root\\wmi path MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2>/dev/null | grep -oP '\d+' | head -1)
            if [[ -n "$temp" ]]; then
                local celsius=$(echo "scale=1; ($temp * 0.1) - 273.15" | bc 2>/dev/null)
                if [[ -n "$celsius" ]] && (( $(echo "$celsius > -50 && $celsius < 150" | bc -l 2>/dev/null || echo 1) )); then
                    echo "$celsius"
                    return
                fi
            fi
        fi
        
        # Try PowerShell
        if command -v powershell.exe &> /dev/null; then
            local temp=$(powershell.exe -Command "Get-WmiObject -Class Win32_TemperatureProbe | Select-Object -ExpandProperty CurrentReading" 2>/dev/null | grep -oP '\d+' | head -1)
            if [[ -n "$temp" ]]; then
                local celsius=$(echo "scale=1; ($temp / 10) - 273.15" | bc 2>/dev/null)
                if [[ -n "$celsius" ]] && (( $(echo "$celsius > -50 && $celsius < 150" | bc -l 2>/dev/null || echo 1) )); then
                    echo "$celsius"
                    return
                fi
            fi
        fi
        
        # Try simple load-based estimation
        local load1=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
        if [[ -n "$load1" ]]; then
            local estimated_temp=$(echo "scale=1; 40 + ($load1 * 5)" | bc 2>/dev/null)
            if [[ -n "$estimated_temp" ]] && (( $(echo "$estimated_temp > 20 && $estimated_temp < 80" | bc -l 2>/dev/null || echo 1) )); then
                echo "${estimated_temp}*"
                return
            fi
        fi
        
        # If all WSL methods fail, return a default message
        echo "WSL-N/A"
        return
    fi
    
    # Method 1: Try vcgencmd first (most reliable for Raspberry Pi)
    if command -v vcgencmd &> /dev/null; then
        local temp=$(vcgencmd measure_temp 2>/dev/null | grep -oP '\d+\.\d+')
        if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
            echo "$temp"
            return
        fi
    fi
    
    # Method 2: Try multiple thermal zone locations
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [[ -f "$zone" ]]; then
            local temp=$(awk '{printf "%.1f", $1/1000}' "$zone" 2>/dev/null)
            if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
                echo "$temp"
                return
            fi
        fi
    done
    
    # Method 3: Try /sys/class/hwmon (alternative location)
    for hwmon in /sys/class/hwmon/hwmon*/temp*_input; do
        if [[ -f "$hwmon" ]]; then
            local temp=$(awk '{printf "%.1f", $1/1000}' "$hwmon" 2>/dev/null)
            if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
                echo "$temp"
                return
            fi
        fi
    done
    
    # Method 4: Try sensors command
    if command -v sensors &> /dev/null; then
        local temp=$(sensors 2>/dev/null | grep -i "cpu\|core\|temp" | grep -oP '\d+\.\d+' | head -1)
        if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
            echo "$temp"
            return
        fi
    fi
    
    # Method 5: Try acpi command
    if command -v acpi &> /dev/null; then
        local temp=$(acpi -t 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
        if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
            echo "$temp"
            return
        fi
    fi
    
    # Method 6: Try /proc/acpi/thermal_zone (older systems)
    for thermal in /proc/acpi/thermal_zone/*/temperature; do
        if [[ -f "$thermal" ]]; then
            local temp=$(awk '{gsub(/[^0-9.]/, "", $2); print $2}' "$thermal" 2>/dev/null)
            if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
                echo "$temp"
                return
            fi
        fi
    done
    
    # Method 7: Try cat /proc/cpuinfo | grep -i temperature (some ARM systems)
    local temp=$(grep -i "temperature\|temp" /proc/cpuinfo 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
    if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
        echo "$temp"
        return
    fi
    
    # Method 8: Try dmesg for temperature info
    local temp=$(dmesg 2>/dev/null | grep -i "temperature\|temp" | grep -oP '\d+\.\d+' | tail -1)
    if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
        echo "$temp"
        return
    fi
    
    # Method 9: WSL specific (Windows Subsystem for Linux)
    if [[ -n "$WSL_DISTRO_NAME" ]] || [[ -n "$WSLENV" ]] || grep -q Microsoft /proc/version 2>/dev/null; then
        # Try to get temperature from Windows via wmic (if available)
        if command -v wmic &> /dev/null; then
            local temp=$(wmic /namespace:\\\\root\\wmi path MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2>/dev/null | grep -oP '\d+' | head -1)
            if [[ -n "$temp" ]]; then
                # Convert from Kelvin (multiply by 0.1) and then to Celsius (subtract 273.15)
                local celsius=$(echo "scale=1; ($temp * 0.1) - 273.15" | bc 2>/dev/null)
                if [[ -n "$celsius" ]] && (( $(echo "$celsius > -50 && $celsius < 150" | bc -l 2>/dev/null || echo 1) )); then
                    echo "$celsius"
                    return
                fi
            fi
        fi
        
        # Try PowerShell via wsl command (if available)
        if command -v powershell.exe &> /dev/null; then
            local temp=$(powershell.exe -Command "Get-WmiObject -Class Win32_TemperatureProbe | Select-Object -ExpandProperty CurrentReading" 2>/dev/null | grep -oP '\d+' | head -1)
            if [[ -n "$temp" ]]; then
                # Convert from tenths of Kelvin to Celsius
                local celsius=$(echo "scale=1; ($temp / 10) - 273.15" | bc 2>/dev/null)
                if [[ -n "$celsius" ]] && (( $(echo "$celsius > -50 && $celsius < 150" | bc -l 2>/dev/null || echo 1) )); then
                    echo "$celsius"
                    return
                fi
            fi
        fi
        
        # Try reading from /proc/stat and estimate (very rough approximation)
        local load1=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
        if [[ -n "$load1" ]] && (( $(echo "$load1 > 0" | bc -l 2>/dev/null || echo 1) )); then
            # Very rough estimation: base temp + load factor
            local estimated_temp=$(echo "scale=1; 35 + ($load1 * 10)" | bc 2>/dev/null)
            if [[ -n "$estimated_temp" ]] && (( $(echo "$estimated_temp > 20 && $estimated_temp < 80" | bc -l 2>/dev/null || echo 1) )); then
                echo "${estimated_temp}*"  # * indicates estimated
                return
            fi
        fi
        
        echo "WSL*"  # Indicate WSL limitation
        return
    fi
    
    # Method 10: macOS specific
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v osx-cpu-temp &> /dev/null; then
            local temp=$(osx-cpu-temp 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
            if [[ -n "$temp" ]]; then
                echo "$temp"
                return
            fi
        fi
        
        # Try system_profiler on macOS
        local temp=$(system_profiler SPHardwareDataType 2>/dev/null | grep -i "temperature" | grep -oP '\d+\.\d+' | head -1)
        if [[ -n "$temp" ]]; then
            echo "$temp"
            return
        fi
    fi
    
    # Method 10: Try reading from /sys/devices/virtual/thermal (some systems)
    for thermal in /sys/devices/virtual/thermal/thermal_zone*/temp; do
        if [[ -f "$thermal" ]]; then
            local temp=$(awk '{printf "%.1f", $1/1000}' "$thermal" 2>/dev/null)
            if [[ -n "$temp" ]] && (( $(echo "$temp > -50 && $temp < 150" | bc -l 2>/dev/null || echo 1) )); then
                echo "$temp"
                return
            fi
        fi
    done
    
    # If all methods fail, return N/A
    echo "N/A"
}

# Diagnostic function to help debug temperature detection
diagnose_temperature() {
    echo -e "${YELLOW}=== Temperature Detection Diagnostic ===${NC}"
    echo ""
    
    echo "1. Platform detected: $PLATFORM"
    echo "2. OSTYPE: $OSTYPE"
    echo "3. WSL Detection:"
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        echo "   WSL_DISTRO_NAME: $WSL_DISTRO_NAME"
    fi
    if [[ -n "$WSLENV" ]]; then
        echo "   WSLENV: $WSLENV"
    fi
    if grep -q Microsoft /proc/version 2>/dev/null; then
        echo "   Microsoft detected in /proc/version: YES"
    else
        echo "   Microsoft detected in /proc/version: NO"
    fi
    echo ""
    
    echo "3. Checking thermal zones:"
    if ls /sys/class/thermal/thermal_zone*/temp 2>/dev/null; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            if [[ -f "$zone" ]]; then
                echo "   $zone: $(cat "$zone" 2>/dev/null || echo "unreadable")"
            fi
        done
    else
        echo "   No thermal zones found"
    fi
    echo ""
    
    echo "4. Checking hwmon sensors:"
    if ls /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null; then
        for hwmon in /sys/class/hwmon/hwmon*/temp*_input; do
            if [[ -f "$hwmon" ]]; then
                echo "   $hwmon: $(cat "$hwmon" 2>/dev/null || echo "unreadable")"
            fi
        done
    else
        echo "   No hwmon temperature sensors found"
    fi
    echo ""
    
    echo "5. Checking commands:"
    echo "   vcgencmd: $(command -v vcgencmd || echo "not found")"
    echo "   sensors: $(command -v sensors || echo "not found")"
    echo "   acpi: $(command -v acpi || echo "not found")"
    echo ""
    
    echo "6. Testing vcgencmd:"
    if command -v vcgencmd &> /dev/null; then
        echo "   $(vcgencmd measure_temp 2>&1)"
    else
        echo "   vcgencmd not available"
    fi
    echo ""
    
    echo "7. Testing sensors:"
    if command -v sensors &> /dev/null; then
        sensors 2>&1 | head -10
    else
        echo "   sensors not available"
    fi
    echo ""
    
    echo "8. Testing acpi:"
    if command -v acpi &> /dev/null; then
        echo "   $(acpi -t 2>&1)"
    else
        echo "   acpi not available"
    fi
    echo ""
    
    echo "9. CPU info temperature:"
    grep -i "temperature\|temp" /proc/cpuinfo 2>/dev/null || echo "   No temperature info in /proc/cpuinfo"
    echo ""
    
    echo "10. WSL-specific tests:"
    if [[ -n "$WSL_DISTRO_NAME" ]] || [[ -n "$WSLENV" ]] || grep -q Microsoft /proc/version 2>/dev/null; then
        echo "   wmic: $(command -v wmic || echo "not found")"
        echo "   powershell.exe: $(command -v powershell.exe || echo "not found")"
        echo "   Testing wmic:"
        if command -v wmic &> /dev/null; then
            echo "   $(wmic /namespace:\\\\root\\wmi path MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2>&1 | head -3)"
        fi
        echo "   Testing PowerShell:"
        if command -v powershell.exe &> /dev/null; then
            echo "   $(powershell.exe -Command "Get-WmiObject -Class Win32_TemperatureProbe | Select-Object -ExpandProperty CurrentReading" 2>&1 | head -2)"
        fi
        echo "   Load average estimation:"
        echo "   $(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "unavailable")"
    else
        echo "   Not running in WSL"
    fi
    echo ""
    
    echo "11. Current temperature reading:"
    local temp_result=$(get_cpu_temp)
    echo "   $temp_result"
    if [[ "$temp_result" == "WSL*" ]]; then
        echo -e "   ${YELLOW}Note: WSL cannot access hardware temperature sensors${NC}"
        echo -e "   ${YELLOW}Consider running this script directly on Windows or a native Linux system${NC}"
    elif [[ "$temp_result" == *"*" ]]; then
        echo -e "   ${YELLOW}Note: Temperature is estimated (* indicates approximation)${NC}"
    fi
}

stress_test_with_monitoring() {
    log_info "${RED}Stress Test with temperature monitoring${NC}"
    
    local duration=${1:-60}
    local max_temp=0
    local temp_readings=()
    
    echo -e "${YELLOW}Test duration: ${duration}s${NC}"
    echo -e "${YELLOW}Initial temperature: $(get_cpu_temp)°C${NC}"
    
    # Launch stress-ng in background
    if ! command -v stress-ng &> /dev/null; then
        log_warn "stress-ng not installed, installing..."
        install_package stress-ng
    fi
    
    local cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu)
    stress-ng --cpu "$cores" --timeout "${duration}s" &> /dev/null &
    local stress_pid=$!
    
    # Real-time monitoring
    local elapsed=0
    while kill -0 $stress_pid 2>/dev/null; do
        local temp=$(get_cpu_temp)
        if [[ "$temp" != "N/A" ]]; then
            temp_readings+=("$temp")
            if (( $(echo "$temp > $max_temp" | bc -l) )); then
                max_temp=$temp
            fi
            
            local color=$GREEN
            if (( $(echo "$temp > 70" | bc -l) )); then
                color=$RED
            elif (( $(echo "$temp > 60" | bc -l) )); then
                color=$YELLOW
            fi
            
            printf "\r${color}[%3ds] Temp: %5.1f°C | Max: %5.1f°C${NC}" \
                $elapsed "$temp" "$max_temp"
        fi
        
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    wait $stress_pid 2>/dev/null || true
    
    # Calculate average and min
    if [ ${#temp_readings[@]} -eq 0 ]; then
        echo ""
        echo ""
        echo -e "${CYAN}Stress test results:${NC}"
        echo -e "  Temperature monitoring: N/A (no valid readings)"
        return
    fi
    
    local sum=0
    local min_temp=${temp_readings[0]}
    for temp in "${temp_readings[@]}"; do
        sum=$(echo "$sum + $temp" | bc)
        if (( $(echo "$temp < $min_temp" | bc -l) )); then
            min_temp=$temp
        fi
    done
    local avg_temp=$(echo "scale=1; $sum / ${#temp_readings[@]}" | bc)
    
    echo ""
    echo ""
    echo -e "${CYAN}Stress test results:${NC}"
    echo -e "  Min temperature: ${min_temp}°C"
    echo -e "  Avg temperature: ${avg_temp}°C"
    echo -e "  Max temperature: ${max_temp}°C"
}

# === FEATURE 2: COMPARISON WITH HISTORY ===

compare_with_history() {
    log_info "${MAGENTA}Comparison with history${NC}"
    
    local current_score=$(calculate_overall_score)
    
    # Get the last 5 scores
    local history=$(sqlite3 "$DB_FILE" "
        SELECT overall_score 
        FROM benchmarks 
        WHERE overall_score > 0
        ORDER BY timestamp DESC 
        LIMIT 5;
    ")
    
    if [[ -z "$history" ]]; then
        echo -e "${YELLOW}No history available${NC}"
        return
    fi
    
    local scores=($history)
    local sum=0
    local count=${#scores[@]}
    
    for score in "${scores[@]}"; do
        sum=$((sum + score))
    done
    
    local avg_score=$((sum / count))
    local diff=$((current_score - avg_score))
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}      COMPARISON WITH HISTORY          ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} Current score:         %3d%%          ${CYAN}║${NC}\n" "$current_score"
    printf "${CYAN}║${NC} Historical average:   %3d%%          ${CYAN}║${NC}\n" "$avg_score"
    
    if [[ $diff -gt 0 ]]; then
        printf "${CYAN}║${NC} Difference:           ${GREEN}+%3d%%${NC}          ${CYAN}║${NC}\n" "$diff"
        echo -e "${CYAN}║${NC}                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}✓ Performance improving!${NC}           ${CYAN}║${NC}"
    elif [[ $diff -lt 0 ]]; then
        printf "${CYAN}║${NC} Difference:           ${RED}%4d%%${NC}          ${CYAN}║${NC}\n" "$diff"
        echo -e "${CYAN}║${NC}                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}⚠ Performance declining${NC}           ${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${NC} Difference:             0%          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}= Performance stable${NC}              ${CYAN}║${NC}"
    fi
    
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
}

# === FEATURE 3: HTML CHART GENERATION ===

generate_html_report() {
    log_info "${BLUE}Generating HTML report${NC}"
    
    local html_file="${RESULTS_DIR}/report_$(date +%Y%m%d_%H%M%S).html"
    
    # Get the last 10 benchmarks
    local data=$(sqlite3 "$DB_FILE" "
        SELECT 
            datetime(timestamp, 'unixepoch') as date,
            overall_score,
            cpu_single,
            cpu_multi,
            memory,
            disk_read,
            disk_write
        FROM benchmarks 
        ORDER BY timestamp DESC 
        LIMIT 10;
    ")
    
    # Prepare data for Chart.js
    local dates=()
    local scores=()
    local cpu_data=()
    local memory_data=()
    local disk_data=()
    
    while IFS='|' read -r date score cpu_s cpu_m mem disk_r disk_w; do
        dates+=("\"$date\"")
        scores+=("$score")
        cpu_data+=("$cpu_s")
        memory_data+=("$mem")
        disk_data+=("$disk_r")
    done <<< "$data"
    
    # Reverse order for chronological display
    dates=($(printf '%s\n' "${dates[@]}" | tac))
    scores=($(printf '%s\n' "${scores[@]}" | tac))
    cpu_data=($(printf '%s\n' "${cpu_data[@]}" | tac))
    memory_data=($(printf '%s\n' "${memory_data[@]}" | tac))
    disk_data=($(printf '%s\n' "${disk_data[@]}" | tac))
    
    cat > "$html_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>RPi Benchmark Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, sans-serif; 
            background: #1a1a1a; 
            color: #e0e0e0;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: #00d4ff; text-align: center; }
        .chart-container { 
            background: #2a2a2a; 
            border-radius: 10px; 
            padding: 20px; 
            margin: 20px 0;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        }
        canvas { max-height: 400px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 RPi Benchmark Report</h1>
        <p style="text-align:center; color: #888;">Generated on $(date '+%Y-%m-%d %H:%M:%S')</p>
        
        <div class="chart-container">
            <canvas id="overallChart"></canvas>
        </div>
        
        <div class="chart-container">
            <canvas id="cpuChart"></canvas>
        </div>
        
        <div class="chart-container">
            <canvas id="performanceChart"></canvas>
        </div>
    </div>
    
    <script>
        const dates = [$(IFS=,; echo "${dates[*]}")];
        const scores = [$(IFS=,; echo "${scores[*]}")];
        const cpuData = [$(IFS=,; echo "${cpu_data[*]}")];
        const memoryData = [$(IFS=,; echo "${memory_data[*]}")];
        const diskData = [$(IFS=,; echo "${disk_data[*]}")];
        
        // Score global
        new Chart(document.getElementById('overallChart'), {
            type: 'line',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Score Global (%)',
                    data: scores,
                    borderColor: '#00d4ff',
                    backgroundColor: 'rgba(0, 212, 255, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: { display: true, text: 'Overall Score Evolution', color: '#e0e0e0' },
                    legend: { labels: { color: '#e0e0e0' } }
                },
                scales: {
                    y: { 
                        beginAtZero: true, 
                        max: 120,
                        grid: { color: '#444' },
                        ticks: { color: '#e0e0e0' }
                    },
                    x: { 
                        grid: { color: '#444' },
                        ticks: { color: '#e0e0e0' }
                    }
                }
            }
        });
        
        // CPU Performance
        new Chart(document.getElementById('cpuChart'), {
            type: 'bar',
            data: {
                labels: dates,
                datasets: [{
                    label: 'CPU Single-Thread',
                    data: cpuData,
                    backgroundColor: '#ff6b6b'
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: { display: true, text: 'Performance CPU', color: '#e0e0e0' },
                    legend: { labels: { color: '#e0e0e0' } }
                },
                scales: {
                    y: { 
                        beginAtZero: true,
                        grid: { color: '#444' },
                        ticks: { color: '#e0e0e0' }
                    },
                    x: { 
                        grid: { color: '#444' },
                        ticks: { color: '#e0e0e0' }
                    }
                }
            }
        });
        
        // Comparaison Mémoire/Disque
        new Chart(document.getElementById('performanceChart'), {
            type: 'line',
            data: {
                labels: dates,
                datasets: [
                    {
                        label: 'Mémoire (MB/s)',
                        data: memoryData,
                        borderColor: '#4ecdc4',
                        backgroundColor: 'transparent'
                    },
                    {
                        label: 'Disque Lecture (MB/s)',
                        data: diskData,
                        borderColor: '#ffe66d',
                        backgroundColor: 'transparent'
                    }
                ]
            },
            options: {
                responsive: true,
                plugins: {
                    title: { display: true, text: 'Memory & Disk Performance', color: '#e0e0e0' },
                    legend: { labels: { color: '#e0e0e0' } }
                },
                scales: {
                    y: { 
                        beginAtZero: true,
                        grid: { color: '#444' },
                        ticks: { color: '#e0e0e0' }
                    },
                    x: { 
                        grid: { color: '#444' },
                        ticks: { color: '#e0e0e0' }
                    }
                }
            }
        });
    </script>
</body>
</html>
EOF
    
    log_info "Report generated: ${GREEN}$html_file${NC}"
    echo -e "${YELLOW}Open the file in a browser to view the charts${NC}"
}

# === FEATURE 4: DETAILED JSON EXPORT ===

export_json() {
    log_info "${CYAN}Export JSON${NC}"
    
    local json_file="${RESULTS_DIR}/benchmark_$(date +%Y%m%d_%H%M%S).json"
    local timestamp=$(date +%s)
    
    cat > "$json_file" <<EOF
{
  "timestamp": $timestamp,
  "date": "$(date -Iseconds)",
  "platform": "$PLATFORM",
  "system": {
    "cpu_model": "$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "N/A")",
    "cpu_cores": $(nproc 2>/dev/null || sysctl -n hw.ncpu),
    "ram_total": $(free -m 2>/dev/null | grep Mem: | awk '{print $2}' || echo 0),
    "disk_total": $(df -BG / 2>/dev/null | tail -1 | awk '{print $2}' | sed 's/G//' || echo 0)
  },
  "benchmarks": {
    "cpu_single": ${BENCHMARK_RESULTS[cpu_single]},
    "cpu_multi": ${BENCHMARK_RESULTS[cpu_multi]},
    "memory": ${BENCHMARK_RESULTS[memory]},
    "disk_read": ${BENCHMARK_RESULTS[disk_read]},
    "disk_write": ${BENCHMARK_RESULTS[disk_write]},
    "network_down": ${BENCHMARK_RESULTS[network_down]},
    "network_up": ${BENCHMARK_RESULTS[network_up]},
    "network_ping": ${BENCHMARK_RESULTS[network_ping]}
  },
  "scores": {
    "cpu_single": $(calculate_score "cpu_single" "${BENCHMARK_RESULTS[cpu_single]}"),
    "cpu_multi": $(calculate_score "cpu_multi" "${BENCHMARK_RESULTS[cpu_multi]}"),
    "memory": $(calculate_score "memory" "${BENCHMARK_RESULTS[memory]}"),
    "disk_read": $(calculate_score "disk_read" "${BENCHMARK_RESULTS[disk_read]}"),
    "disk_write": $(calculate_score "disk_write" "${BENCHMARK_RESULTS[disk_write]}"),
    "overall": $(calculate_overall_score)
  }
}
EOF
    
    log_info "JSON export: ${GREEN}$json_file${NC}"
}

# === FEATURE 5: INTELLIGENT RECOMMENDATIONS ===

generate_recommendations() {
    log_info "${YELLOW}Analysis and recommendations${NC}"
    
    local overall=$(calculate_overall_score)
    local cpu_score=$(calculate_score "cpu_single" "${BENCHMARK_RESULTS[cpu_single]}")
    local mem_score=$(calculate_score "memory" "${BENCHMARK_RESULTS[memory]}")
    local disk_score=$(calculate_score "disk_read" "${BENCHMARK_RESULTS[disk_read]}")
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}RECOMMENDATIONS${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    
    # Global analysis
    if [[ $overall -gt 90 ]]; then
        echo -e "${CYAN}║${NC} ${GREEN}✓ Excellent performance!${NC}                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   Your system is very performant.              ${CYAN}║${NC}"
    elif [[ $overall -gt 70 ]]; then
        echo -e "${CYAN}║${NC} ${YELLOW}○ Good performance${NC}                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   Some optimizations possible.                 ${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${NC} ${RED}⚠ Poor performance${NC}                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   Optimizations recommended.                   ${CYAN}║${NC}"
    fi
    
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    
    # Specific recommendations
    if [[ $cpu_score -lt 70 ]]; then
        echo -e "${CYAN}║${NC} ${RED}CPU:${NC} Low score (${cpu_score}%)                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   → Check background processes                ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   → Increase CPU frequency if possible        ${CYAN}║${NC}"
    fi
    
    if [[ $mem_score -lt 70 ]]; then
        echo -e "${CYAN}║${NC} ${RED}MEMORY:${NC} Low score (${mem_score}%)                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   → Free up RAM                               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   → Check swap usage                          ${CYAN}║${NC}"
    fi
    
    if [[ $disk_score -lt 70 ]]; then
        echo -e "${CYAN}║${NC} ${RED}DISK:${NC} Low score (${disk_score}%)                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   → Switch to SSD if possible                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   → Check filesystem status                   ${CYAN}║${NC}"
    fi
    
    # Temperature
    local temp=$(get_cpu_temp)
    if [[ "$temp" != "N/A" ]]; then
        if (( $(echo "$temp > 70" | bc -l) )); then
            echo -e "${CYAN}║${NC} ${RED}TEMPERATURE:${NC} High (${temp}°C)                ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC}   → Improve cooling                         ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC}   → Check case ventilation                  ${CYAN}║${NC}"
        fi
    fi
    
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

# === RESULTS DISPLAY ===

display_results() {
    local overall=$(calculate_overall_score)
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}             ${YELLOW}BENCHMARK RESULTS${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${NC}"
    
    for category in cpu_single cpu_multi memory disk_read disk_write network_down network_up network_ping; do
        local value=${BENCHMARK_RESULTS[$category]}
        local score=$(calculate_score "$category" "$value")
        local ref=${REFERENCE_SCORES[$category]:-"N/A"}
        
        # Determine color based on score
        local color=$RED
        if [[ $score -gt 80 ]]; then
            color=$GREEN
        elif [[ $score -gt 50 ]]; then
            color=$YELLOW
        fi
        
        local label=""
        case $category in
            cpu_single) label="CPU Single-Thread" ;;
            cpu_multi) label="CPU Multi-Thread" ;;
            memory) label="Mémoire" ;;
            disk_read) label="Disque (Lecture)" ;;
            disk_write) label="Disque (Écriture)" ;;
            network_down) label="Réseau (Download)" ;;
            network_up) label="Réseau (Upload)" ;;
            network_ping) label="Réseau (Ping)" ;;
        esac
        
        printf "${CYAN}║${NC} %-20s ${color}%6.2f${NC} | Score: ${color}%3d%%${NC} (Ref: %s) ${CYAN}║${NC}\n" \
            "$label" "$value" "$score" "$ref"
    done
    
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${NC}"
    
    local overall_color=$RED
    if [[ $overall -gt 80 ]]; then
        overall_color=$GREEN
    elif [[ $overall -gt 50 ]]; then
        overall_color=$YELLOW
    fi
    
    printf "${CYAN}║${NC}        ${YELLOW}OVERALL SCORE:${NC} ${overall_color}%3d%%${NC}                      ${CYAN}║${NC}\n" "$overall"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
}

# === SAVE ===

save_to_database() {
    local timestamp=$(date +%s)
    local overall=$(calculate_overall_score)
    
    sqlite3 "$DB_FILE" <<EOF
INSERT INTO benchmarks (
    timestamp, cpu_single, cpu_multi, memory,
    disk_read, disk_write, network_down, network_up,
    network_ping, overall_score, platform
) VALUES (
    $timestamp,
    ${BENCHMARK_RESULTS[cpu_single]},
    ${BENCHMARK_RESULTS[cpu_multi]},
    ${BENCHMARK_RESULTS[memory]},
    ${BENCHMARK_RESULTS[disk_read]},
    ${BENCHMARK_RESULTS[disk_write]},
    ${BENCHMARK_RESULTS[network_down]},
    ${BENCHMARK_RESULTS[network_up]},
    ${BENCHMARK_RESULTS[network_ping]},
    $overall,
    '$PLATFORM'
);
EOF
    
    log_info "Results saved to database"
}

export_csv() {
    local csv_file="${RESULTS_DIR}/benchmark_$(date +%Y%m%d_%H%M%S).csv"
    
    sqlite3 -header -csv "$DB_FILE" "SELECT * FROM benchmarks ORDER BY timestamp DESC LIMIT 10;" > "$csv_file"
    
    log_info "Results exported to: $csv_file"
}

# === MAIN MENU ===

show_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}       ${YELLOW}RPi Benchmark v${SCRIPT_VERSION}${NC}                               ${CYAN}║${NC}"                      
        echo -e "${CYAN}╠═══════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}BENCHMARKS${NC}                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  1. Run all benchmarks                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  2. CPU Benchmark                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  3. Memory Benchmark                       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  4. Disk Benchmark                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  5. Network Benchmark                      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}ADVANCED FEATURES${NC}                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  6. Stress Test + Temperature Monitoring      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  7. Compare with history                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  8. Generate HTML report                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  9. Detailed JSON export                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} 10. Intelligent recommendations           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}OTHER${NC}                                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} 11. Show history                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} 12. Export to CSV                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} 14. Temperature diagnostic                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} 13. Exit                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "Choice: " choice
        
        case $choice in
            1) run_all_benchmarks ;;
            2) benchmark_cpu_single; benchmark_cpu_multi ;;
            3) benchmark_memory ;;
            4) benchmark_disk ;;
            5) benchmark_network ;;
            6) stress_test_with_monitoring ;;
            7) compare_with_history ;;
            8) generate_html_report ;;
            9) export_json ;;
            10) generate_recommendations ;;
            11) show_history ;;
            12) export_csv ;;
            14) diagnose_temperature ;;
            13) exit 0 ;;
            *) log_error "Invalid choice" ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

run_all_benchmarks() {
    log_info "Starting all benchmarks..."
    
    benchmark_cpu_single
    benchmark_cpu_multi
    benchmark_memory
    benchmark_disk
    benchmark_network
    
    display_results
    save_to_database
    
    # Automatic features after complete benchmark
    echo ""
    log_info "Generating complementary analyses..."
    
    compare_with_history
    generate_recommendations
    
    echo ""
    read -p "Generate HTML report? (y/n): " answer
    if [[ "$answer" =~ ^[yY]$ ]]; then
        generate_html_report
    fi
    
    read -p "Export to JSON? (y/n): " answer
    if [[ "$answer" =~ ^[yY]$ ]]; then
        export_json
    fi
}

show_history() {
    echo -e "${CYAN}History of the last 10 benchmarks:${NC}"
    sqlite3 -header -column "$DB_FILE" "
        SELECT 
            datetime(timestamp, 'unixepoch') as date,
            overall_score as score,
            cpu_single,
            memory,
            disk_read
        FROM benchmarks 
        ORDER BY timestamp DESC 
        LIMIT 10;
    "
}

# === MAIN ===

main() {
    init_environment
    init_database
    check_dependencies
    
    if [[ "$1" == "--auto" ]]; then
        run_all_benchmarks
    else
        show_menu
    fi
}

main "$@"