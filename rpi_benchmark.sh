#!/bin/bash

# =====================================================
# Script de Benchmarking et Monitoring pour Raspberry Pi
# =====================================================

# Arrêt en cas d'erreur
set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
LOG_FILE="benchmark_results_$(date +%Y%m%d_%H%M%S).log"
TEMP_THRESHOLD=70 # Seuil de température critique en degrés Celsius
RESULTS_DIR="benchmark_results"
HISTORY_DB="$RESULTS_DIR/benchmark_history.db"
MAX_LOGS=10 # Nombre maximum de fichiers de log à conserver

# Détection de la plateforme
PLATFORM="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" == "raspbian" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        PLATFORM="raspbian"
    elif [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
        PLATFORM="ubuntu"
    fi
fi

# Fonction pour afficher une erreur et quitter
display_error() {
    echo -e "${RED}Erreur: $1${NC}"
    exit 1
}

# Fonction pour installer un paquet
install_package() {
    local package=$1
    
    case $PLATFORM in
        "macos")
            brew install "$package"
            ;;
        "raspbian"|"ubuntu")
            apt-get install -y "$package"
            ;;
        *)
            display_error "Plateforme non supportée: $PLATFORM"
            ;;
    esac
}

# Fonction pour installer les paquets requis
install_packages() {
    local packages=()
    
    # Définir les paquets en fonction de la plateforme
    case $PLATFORM in
        "macos")
            packages=("sysbench" "stress-ng" "speedtest-cli")
            ;;
        *)
            packages=("sysbench" "stress-ng" "speedtest-cli" "bc" "dnsutils" "hdparm")
            ;;
    esac

    local missing_deps=()

    # Vérifier si nous sommes sur macOS et si Homebrew est installé
    if [[ "$PLATFORM" == "macos" ]] && ! command -v brew &> /dev/null; then
        display_error "Homebrew n'est pas installé. Veuillez l'installer depuis https://brew.sh"
    fi

    # Vérifier les dépendances manquantes
    for package in "${packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            missing_deps+=("$package")
        fi
    done

    # Installer les dépendances manquantes
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${YELLOW}Installation des paquets requis...${NC}"
        case $PLATFORM in
            "macos")
                for package in "${missing_deps[@]}"; do
                    brew install "$package" || display_error "Échec de l'installation de $package"
                done
                ;;
            "raspbian"|"ubuntu")
                apt-get update
                for package in "${missing_deps[@]}"; do
                    apt-get install -y "$package" || display_error "Échec de l'installation de $package"
                done
                ;;
            *)
                display_error "Plateforme non supportée: $PLATFORM"
                ;;
        esac
    fi
}

# Fonction pour obtenir la température CPU
get_cpu_temp() {
    case $PLATFORM in
        "macos")
            # Sur macOS, utiliser osx-cpu-temp si disponible
            if command -v osx-cpu-temp &> /dev/null; then
                echo "$(osx-cpu-temp)"
            else
                echo "N/A"
            fi
            ;;
        "raspbian")
            # Sur Raspberry Pi
            if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
                echo "$(awk '{printf "%.1f°C", $1/1000}' /sys/class/thermal/thermal_zone0/temp)"
            else
                echo "N/A"
            fi
            ;;
        *)
            echo "N/A"
            ;;
    esac
}

# Fonction pour afficher l'en-tête
show_header() {
    clear
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}    Script de Benchmarking Raspberry Pi v2.0        ${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo -e "${YELLOW}Log file: $LOG_FILE${NC}"
    echo -e "${BLUE}=====================================================${NC}\n"
}

# Fonction pour logger les résultats
log_result() {
    local message="$1"
    echo -e "$message" | tee -a "$LOG_FILE"
}

# Fonction pour obtenir les informations hardware
get_hardware_info() {
    log_result "\n${BLUE}=== INFORMATIONS HARDWARE ===${NC}"
    
    # Informations CPU
    log_result "${YELLOW}CPU:${NC}"
    case $PLATFORM in
        "macos")
            log_result "  Modèle: $(sysctl -n machdep.cpu.brand_string)"
            log_result "  Architecture: $(uname -m)"
            log_result "  Cœurs: $(sysctl -n hw.ncpu)"
            ;;
        *)
            log_result "  Modèle: $(cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')"
            log_result "  Architecture: $(uname -m)"
            log_result "  Cœurs: $(nproc)"
            ;;
    esac
    
    # Informations Mémoire
    log_result "${YELLOW}Mémoire:${NC}"
    case $PLATFORM in
        "macos")
            log_result "  Total: $(( $(sysctl -n hw.memsize) / 1024 / 1024 ))M"
            ;;
        *)
            log_result "  Total: $(free -h | awk '/^Mem:/ {print $2}')"
            log_result "  Swap: $(free -h | awk '/^Swap:/ {print $2}')"
            ;;
    esac
    
    # Informations Disque
    log_result "${YELLOW}Disque:${NC}"
    case $PLATFORM in
        "macos")
            log_result "  Total: $(df -h / | awk 'NR==2 {print $2}')"
            log_result "  Utilisé: $(df -h / | awk 'NR==2 {print $3}')"
            log_result "  Disponible: $(df -h / | awk 'NR==2 {print $4}')"
            ;;
        *)
            log_result "  Total: $(df -h --total | awk '/total/ {print $2}')"
            log_result "  Utilisé: $(df -h --total | awk '/total/ {print $3}')"
            log_result "  Disponible: $(df -h --total | awk '/total/ {print $4}')"
            ;;
    esac
    
    # Informations supplémentaires spécifiques à la plateforme
    log_result "${YELLOW}Informations supplémentaires:${NC}"
    log_result "  Température CPU: $(get_cpu_temp)"
    
    if [[ "$PLATFORM" == "raspbian" ]]; then
        # Informations spécifiques Raspberry Pi
        if command -v vcgencmd &> /dev/null; then
            log_result "  Fréquence CPU: $(vcgencmd get_config int | grep arm_freq | awk -F'=' '{printf "%s MHz", $2}')"
            log_result "  Fréquence GPU: $(vcgencmd get_config int | grep gpu_freq | awk -F'=' '{printf "%s MHz", $2}')"
        fi
    fi
}

# Fonction pour obtenir les informations réseau
get_network_info() {
    log_result "\n${BLUE}=== INFORMATIONS RÉSEAU ===${NC}"
    
    # Informations de base
    log_result "${YELLOW}Configuration réseau:${NC}"
    log_result "  Nom d'hôte: $(hostname)"
    
    case $PLATFORM in
        "macos")
            log_result "  IP interne: $(ipconfig getifaddr en0 2>/dev/null || echo 'N/A')"
            log_result "  Masque de sous-réseau: $(ipconfig getoption en0 subnet_mask 2>/dev/null || echo 'N/A')"
            log_result "  Passerelle: $(netstat -nr | grep default | head -n1 | awk '{print $2}')"
            log_result "  Adresse MAC: $(ifconfig en0 | awk '/ether/{print $2}')"
            ;;
        *)
            log_result "  IP interne: $(hostname -I | awk '{print $1}')"
            log_result "  Masque de sous-réseau: $(ip route | awk '/proto/ {print $3}')"
            log_result "  Passerelle: $(ip route | awk '/default/ {print $3}')"
            log_result "  Adresse MAC: $(ip link | awk '/ether/ {print $2}')"
            ;;
    esac
    
    # IP externe (identique pour toutes les plateformes)
    log_result "  IP externe: $(curl -s ifconfig.me)"
    
    # DNS Servers
    case $PLATFORM in
        "macos")
            log_result "  Serveurs DNS: $(scutil --dns | awk '/nameserver/{print $3}' | sort -u | tr '\n' ' ')"
            ;;
        *)
            log_result "  Serveurs DNS: $(cat /etc/resolv.conf | awk '/nameserver/ {print $2}' | tr '\n' ' ')"
            ;;
    esac
}

# Fonction pour obtenir le nombre de processeurs
get_cpu_cores() {
    case $PLATFORM in
        "macos")
            sysctl -n hw.ncpu
            ;;
        *)
            nproc
            ;;
    esac
}

# Fonction pour formater les nombres
format_number() {
    local number=$1
    if [[ $number =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        printf "%.2f" "$number"
    else
        echo "0.00"
    fi
}

# Fonction pour le benchmark CPU
benchmark_cpu() {
    log_result "\n${BLUE}=== BENCHMARK CPU ===${NC}"
    
    # Test single-thread
    log_result "${YELLOW}Test single-thread:${NC}"
    local results=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>/dev/null)
    local events=$(echo "$results" | grep 'total number of events:' | awk '{print $NF}')
    local time=$(echo "$results" | grep 'total time:' | awk '{print $NF}' | sed 's/s$//')
    local ops=$(echo "$results" | grep 'events per second:' | awk '{print $NF}')
    
    printf "+---------------------+----------------------+\n"
    printf "| ${CYAN}Métrique${NC}            | ${CYAN}Score${NC}                |\n"
    printf "+---------------------+----------------------+\n"
    printf "| Événements          | ${GREEN}%-20s${NC} |\n" "${events:-0}"
    printf "| Temps total         | ${GREEN}%-20s${NC} |\n" "$(format_number "$time") sec"
    printf "| Opérations/sec      | ${GREEN}%-20s${NC} |\n" "$(format_number "$ops")"
    printf "+---------------------+----------------------+\n"
    
    # Test multi-thread
    log_result "${YELLOW}Test multi-thread:${NC}"
    local cpu_cores=$(get_cpu_cores)
    local results=$(sysbench cpu --cpu-max-prime=20000 --threads=$cpu_cores run 2>/dev/null)
    local events=$(echo "$results" | grep 'total number of events:' | awk '{print $NF}')
    local time=$(echo "$results" | grep 'total time:' | awk '{print $NF}' | sed 's/s$//')
    local ops=$(echo "$results" | grep 'events per second:' | awk '{print $NF}')
    
    printf "+---------------------+----------------------+\n"
    printf "| ${CYAN}Métrique${NC}            | ${CYAN}Score${NC}                |\n"
    printf "+---------------------+----------------------+\n"
    printf "| Événements          | ${GREEN}%-20s${NC} |\n" "${events:-0}"
    printf "| Temps total         | ${GREEN}%-20s${NC} |\n" "$(format_number "$time") sec"
    printf "| Opérations/sec      | ${GREEN}%-20s${NC} |\n" "$(format_number "$ops")"
    printf "+---------------------+----------------------+\n"
}

# Fonction pour le benchmark threads
benchmark_threads() {
    log_result "\n${BLUE}=== BENCHMARK THREADS ===${NC}"
    
    local cpu_cores=$(get_cpu_cores)
    local results=$(sysbench threads --threads=$cpu_cores --thread-yields=1000 --thread-locks=8 run 2>/dev/null)
    local time=$(echo "$results" | grep 'total time:' | awk '{print $NF}' | sed 's/s$//')
    local ops=$(echo "$results" | grep 'total number of events:' | awk '{print $NF}')
    local latency=$(echo "$results" | grep 'avg:' | awk '{print $NF}' | sed 's/ms$//')
    
    printf "+----------------------+----------------------+\n"
    printf "| ${CYAN}Métrique${NC}             | ${CYAN}Score${NC}                |\n"
    printf "+----------------------+----------------------+\n"
    printf "| Temps d'exécution    | ${GREEN}%-20s${NC} |\n" "$(format_number "$time") sec"
    printf "| Opérations totales   | ${GREEN}%-20s${NC} |\n" "${ops:-0}"
    printf "| Latence moyenne      | ${GREEN}%-20s${NC} |\n" "$(format_number "$latency") ms"
    printf "+----------------------+----------------------+\n"
}

# Fonction pour le benchmark mémoire
benchmark_memory() {
    log_result "\n${BLUE}=== BENCHMARK MÉMOIRE ===${NC}"
    
    local results=$(sysbench memory --memory-block-size=1K --memory-total-size=10G --memory-access-mode=seq run 2>/dev/null)
    local total_ops=$(echo "$results" | grep 'Total operations:' | awk '{print $NF}')
    local speed=$(echo "$results" | grep 'transferred (' | awk -F'(' '{print $2}' | awk '{print $1}')
    local bw=$(echo "$results" | grep 'transferred (' | awk -F'(' '{print $2}' | awk '{print $3}' | sed 's/)//')
    
    printf "+----------------------+----------------------+\n"
    printf "| ${CYAN}Métrique${NC}             | ${CYAN}Score${NC}                |\n"
    printf "+----------------------+----------------------+\n"
    printf "| Opérations totales   | ${GREEN}%-20s${NC} |\n" "${total_ops:-0}"
    printf "| Vitesse de transfert | ${GREEN}%-20s${NC} |\n" "${speed:-0} ${bw:-MiB/sec}"
    printf "+----------------------+----------------------+\n"
}

# Fonction pour le benchmark disque
benchmark_disk() {
    log_result "\n${BLUE}=== BENCHMARK DISQUE ===${NC}"
    
    # Création d'un fichier temporaire pour les tests
    local test_dir="/tmp/disk_benchmark"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Test d'écriture séquentielle
    log_result "${YELLOW}Test d'écriture séquentielle:${NC}"
    sysbench fileio --file-total-size=2G prepare >/dev/null 2>&1
    local results=$(sysbench fileio --file-total-size=2G --file-test-mode=seqwr run 2>/dev/null)
    local write_speed=$(echo "$results" | grep 'written, MiB/s:' | awk '{print $NF}')
    local write_iops=$(echo "$results" | grep 'writes/s:' | awk '{print $NF}')
    
    # Test de lecture séquentielle
    log_result "${YELLOW}Test de lecture séquentielle:${NC}"
    local results=$(sysbench fileio --file-total-size=2G --file-test-mode=seqrd run 2>/dev/null)
    local read_speed=$(echo "$results" | grep 'read, MiB/s:' | awk '{print $NF}')
    local read_iops=$(echo "$results" | grep 'reads/s:' | awk '{print $NF}')
    
    printf "+---------------------------+--------------------------------+\n"
    printf "| ${CYAN}Métrique${NC}                    | ${CYAN}Score${NC}                          |\n"
    printf "+---------------------------+--------------------------------+\n"
    printf "| Vitesse d'écriture        | ${GREEN}%-26.2f${NC} |\n" "${write_speed:-0} MB/s"
    printf "| IOPS en écriture          | ${GREEN}%-26.2f${NC} |\n" "${write_iops:-0}"
    printf "| Vitesse de lecture        | ${GREEN}%-26.2f${NC} |\n" "${read_speed:-0} MB/s"
    printf "| IOPS en lecture           | ${GREEN}%-26.2f${NC} |\n" "${read_iops:-0}"
    printf "+---------------------------+--------------------------------+\n"
    
    # Nettoyage
    sysbench fileio cleanup >/dev/null 2>&1
    cd - >/dev/null
    rm -rf "$test_dir"
}

# Fonction pour le benchmark réseau
benchmark_network() {
    log_result "\n${BLUE}=== BENCHMARK RÉSEAU ===${NC}"
    
    # Test de latence vers Google DNS
    local ping_result=$(ping -c 5 8.8.8.8 2>/dev/null | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
    
    # Test de débit avec curl
    local download_speed=0
    local upload_speed=0
    
    # Test de téléchargement (fichier test de 10MB depuis un CDN)
    local dl_result=$(curl -s -w "%{speed_download}" -o /dev/null https://speed.hetzner.de/10MB.bin 2>/dev/null)
    if [ -n "$dl_result" ]; then
        download_speed=$(echo "scale=2; $dl_result / 131072" | bc) # Conversion en Mbps
    fi
    
    printf "+----------------------+-------------------+\n"
    printf "| ${CYAN}Métrique${NC}            | ${CYAN}Score${NC}          |\n"
    printf "+----------------------+-------------------+\n"
    printf "| Latence moyenne      | ${GREEN}%-15s${NC} |\n" "${ping_result:-0} ms"
    printf "| Débit descendant     | ${GREEN}%-15s${NC} |\n" "${download_speed:-0} Mbps"
    printf "+----------------------+-------------------+\n"
}

# Fonction pour le stress test et monitoring température
stress_test() {
    log_result "\n${BLUE}=== STRESS TEST ET MONITORING TEMPÉRATURE ===${NC}"
    
    echo -n "Entrez la durée du stress test en secondes: "
    read -r duration
    
    local threads=$(nproc)
    
    log_result "${YELLOW}Démarrage du stress test pour $duration secondes...${NC}"
    log_result "  Nombre de threads: $threads"
    log_result "  Température initiale: $(vcgencmd measure_temp)"
    
    # Démarrer le stress test en arrière-plan
    stress-ng --cpu $threads --timeout "${duration}s" &
    local stress_pid=$!
    
    # Monitoring de la température
    local interval=5
    local elapsed_time=0
    
    while [ $elapsed_time -lt $duration ]; do
        sleep $interval
        elapsed_time=$((elapsed_time + interval))
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp_c=$(echo "scale=1; $temp/1000" | bc)
        
        if (( $(echo "$temp_c > $TEMP_THRESHOLD" | bc -l) )); then
            log_result "${RED}ALERTE: Température CPU élevée: ${temp_c}°C${NC}"
        else
            log_result "  Temps écoulé: $elapsed_time secondes | Température CPU: ${temp_c}°C"
        fi
    done
    
    log_result "${GREEN}Stress test terminé${NC}"
    log_result "  Température finale: $(vcgencmd measure_temp)"
}

# Fonction pour exécuter tous les benchmarks
run_all_benchmarks() {
    benchmark_cpu
    benchmark_threads
    benchmark_memory
    benchmark_disk
    benchmark_network
}

# Fonction pour afficher le menu
show_menu() {
    while true; do
        clear
        show_header
        echo -e "${BLUE}Menu Principal:${NC}"
        echo -e "1. Afficher les informations système"
        echo -e "2. Exécuter tous les benchmarks"
        echo -e "3. Benchmark CPU"
        echo -e "4. Benchmark Threads"
        echo -e "5. Benchmark Mémoire"
        echo -e "6. Benchmark Disque"
        echo -e "7. Benchmark Réseau"
        echo -e "8. Stress Test"
        echo -e "9. Quitter"
        echo -e "\nVotre choix: "
        
        read -r choice
        case $choice in
            1)
                get_hardware_info
                get_network_info
                ;;
            2) run_all_benchmarks ;;
            3) benchmark_cpu ;;
            4) benchmark_threads ;;
            5) benchmark_memory ;;
            6) benchmark_disk ;;
            7) benchmark_network ;;
            8) stress_test ;;
            9) exit 0 ;;
            *) echo -e "${RED}Choix invalide${NC}" ;;
        esac
        
        echo -e "\nAppuyez sur Entrée pour continuer..."
        read -r
    done
}

# Fonction pour initialiser la base de données SQLite
init_db() {
    if ! command -v sqlite3 &> /dev/null; then
        apt-get install -y sqlite3
    fi
    
    mkdir -p "$RESULTS_DIR"
    sqlite3 "$HISTORY_DB" "CREATE TABLE IF NOT EXISTS benchmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        cpu_single_min REAL,
        cpu_single_avg REAL,
        cpu_single_max REAL,
        cpu_multi_min REAL,
        cpu_multi_avg REAL,
        cpu_multi_max REAL,
        memory_min REAL,
        memory_avg REAL,
        memory_max REAL,
        disk_write REAL,
        disk_read REAL,
        network_download REAL,
        network_upload REAL,
        network_ping REAL,
        temperature_max REAL
    );"
}

# Fonction pour exporter les résultats en CSV
export_csv() {
    local csv_file="$RESULTS_DIR/benchmark_results_$(date +%Y%m%d_%H%M%S).csv"
    echo "Date,CPU Single Min,CPU Single Avg,CPU Single Max,CPU Multi Min,CPU Multi Avg,CPU Multi Max,Memory Min,Memory Avg,Memory Max,Disk Write,Disk Read,Network Download,Network Upload,Network Ping,Temperature Max" > "$csv_file"
    sqlite3 -csv "$HISTORY_DB" "SELECT * FROM benchmarks;" >> "$csv_file"
    echo -e "${GREEN}Résultats exportés dans $csv_file${NC}"
}

# Fonction pour exporter les résultats en JSON
export_json() {
    local json_file="$RESULTS_DIR/benchmark_results_$(date +%Y%m%d_%H%M%S).json"
    sqlite3 -json "$HISTORY_DB" "SELECT * FROM benchmarks;" > "$json_file"
    echo -e "${GREEN}Résultats exportés dans $json_file${NC}"
}

# Fonction pour générer un graphique ASCII
generate_ascii_graph() {
    local data=("$@")
    local max=$(printf '%s\n' "${data[@]}" | sort -nr | head -n1)
    local scale=$((max / 20))
    
    for value in "${data[@]}"; do
        local bars=$((value / scale))
        printf "[%-20s] %s\n" "$(printf '#%.0s' $(seq 1 $bars))" "$value"
    done
}

# Fonction pour envoyer une notification
send_notification() {
    local message="$1"
    local type="$2"
    
    # Notification par email
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "RPi Benchmark Alert" "$USER@localhost"
    fi
    
    # Notification Slack (si configuré)
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" "$SLACK_WEBHOOK_URL"
    fi
}

# Fonction pour gérer la rotation des logs
rotate_logs() {
    local logs=($(ls -t "$RESULTS_DIR"/*.log 2>/dev/null))
    if [ ${#logs[@]} -gt $MAX_LOGS ]; then
        for ((i=MAX_LOGS; i<${#logs[@]}; i++)); do
            rm "${logs[$i]}"
        done
    fi
}

# Fonction pour lancer le serveur web
start_web_interface() {
    if ! command -v python3 &> /dev/null; then
        apt-get install -y python3 python3-flask
    fi
    
    cat > "$RESULTS_DIR/web_server.py" << 'EOF'
from flask import Flask, render_template, jsonify
import sqlite3
import os

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/data')
def get_data():
    conn = sqlite3.connect('benchmark_history.db')
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM benchmarks ORDER BY date DESC LIMIT 10")
    data = cursor.fetchall()
    conn.close()
    return jsonify(data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

    mkdir -p "$RESULTS_DIR/templates"
    cat > "$RESULTS_DIR/templates/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>RPi Benchmark Results</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>RPi Benchmark Results</h1>
    <canvas id="resultsChart"></canvas>
    <script>
        fetch('/data')
            .then(response => response.json())
            .then(data => {
                new Chart(document.getElementById('resultsChart'), {
                    type: 'line',
                    data: {
                        labels: data.map(row => row[1]),
                        datasets: [{
                            label: 'CPU Performance',
                            data: data.map(row => row[3])
                        }]
                    }
                });
            });
    </script>
</body>
</html>
EOF

    cd "$RESULTS_DIR" && python3 web_server.py &
    echo -e "${GREEN}Interface web démarrée sur http://localhost:8080${NC}"
}

# Fonction pour planifier les benchmarks
schedule_benchmark() {
    echo -e "${YELLOW}Planification des benchmarks:${NC}"
    echo "1. Toutes les heures"
    echo "2. Tous les jours"
    echo "3. Toutes les semaines"
    echo "4. Retour au menu principal"
    read -r choice
    
    local cron_schedule=""
    case $choice in
        1) cron_schedule="0 * * * *" ;;
        2) cron_schedule="0 0 * * *" ;;
        3) cron_schedule="0 0 * * 0" ;;
        4) return ;;
        *) echo -e "${RED}Choix invalide${NC}" ; return ;;
    esac
    
    (crontab -l 2>/dev/null; echo "$cron_schedule $(pwd)/rpi_benchmark.sh --cron") | crontab -
    echo -e "${GREEN}Benchmark planifié avec succès${NC}"
}

# Fonction pour afficher le menu principal avec dialog
show_dialog_menu() {
    while true; do
        choice=$(dialog --clear \
            --backtitle "RPi Benchmark v2.0" \
            --title "Menu Principal" \
            --menu "Choisissez une option:" \
            15 50 8 \
            1 "Informations système" \
            2 "Exécuter tous les benchmarks" \
            3 "Benchmark CPU" \
            4 "Benchmark Threads" \
            5 "Benchmark Mémoire" \
            6 "Benchmark Disque" \
            7 "Benchmark Réseau" \
            8 "Stress Test" \
            9 "Exporter les résultats" \
            10 "Interface web" \
            11 "Planifier les benchmarks" \
            12 "Quitter" \
            2>&1 >/dev/tty)
            
        case $choice in
            1)
                get_hardware_info
                get_network_info
                ;;
            2) run_all_benchmarks ;;
            3) benchmark_cpu ;;
            4) benchmark_threads ;;
            5) benchmark_memory ;;
            6) benchmark_disk ;;
            7) benchmark_network ;;
            8) stress_test ;;
            9)
                export_csv
                export_json
                ;;
            10) start_web_interface ;;
            11) schedule_benchmark ;;
            12) exit 0 ;;
        esac
        
        read -p "Appuyez sur Entrée pour continuer..."
    done
}

# Fonction principale
main() {
    # Vérification des privilèges administrateur (sauf pour macOS)
    if [[ "$PLATFORM" != "macos" ]] && [[ $EUID -ne 0 ]]; then
        display_error "Ce script doit être exécuté en tant qu'administrateur (root) sur Linux/Raspberry Pi."
    fi

    # Sur macOS, ne pas utiliser sudo pour Homebrew
    if [[ "$PLATFORM" == "macos" ]] && [[ $EUID -eq 0 ]]; then
        display_error "Sur macOS, n'utilisez pas sudo pour exécuter ce script."
    fi
    
    # Installation des paquets requis
    install_packages
    
    # Initialisation de la base de données
    init_db
    
    # Gestion des arguments en ligne de commande
    if [ "$1" == "--cron" ]; then
        run_all_benchmarks
        rotate_logs
    elif [ "$1" == "--dialog" ]; then
        if ! command -v dialog &> /dev/null; then
            install_package "dialog"
        fi
        show_dialog_menu
    else
        show_menu
    fi
}

# Exécution du script
main "$@" 