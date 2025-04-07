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
            if command -v osx-cpu-temp &> /dev/null; then
                osx-cpu-temp | sed 's/°C//'
            else
                echo "N/A"
            fi
            ;;
        "raspbian")
            if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
                awk '{printf "%.1f°C", $1/1000}' /sys/class/thermal/thermal_zone0/temp
            else
                echo "N/A"
            fi
            ;;
        *)
            if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
                awk '{printf "%.1f°C", $1/1000}' /sys/class/thermal/thermal_zone0/temp
            else
                echo "N/A"
            fi
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
        "raspbian")
            log_result "  Modèle: $(cat /proc/cpuinfo | grep "Model" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')"
            log_result "  Architecture: $(uname -m)"
            log_result "  Cœurs: $(nproc)"
            if command -v vcgencmd &> /dev/null; then
                log_result "  Fréquence: $(vcgencmd measure_clock arm | awk -F'=' '{printf "%.0f MHz\n", $2/1000000}')"
                log_result "  Voltage: $(vcgencmd measure_volts core | cut -d'=' -f2)"
            fi
            ;;
        *)
            log_result "  Modèle: $(cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')"
            log_result "  Architecture: $(uname -m)"
            log_result "  Cœurs: $(nproc)"
            ;;
    esac
    
    # Informations Mémoire
    log_result "\n${YELLOW}Mémoire:${NC}"
    case $PLATFORM in
        "macos")
            local total_mem=$(($(sysctl -n hw.memsize) / 1024 / 1024))
            log_result "  Total: ${total_mem}M"
            ;;
        *)
            log_result "  $(free -h | grep "Mem:" | awk '{printf "Total: %s, Utilisé: %s, Libre: %s", $2, $3, $4}')"
            log_result "  Swap: $(free -h | grep "Swap:" | awk '{printf "Total: %s, Utilisé: %s, Libre: %s", $2, $3, $4}')"
            ;;
    esac
    
    # Informations Disque
    log_result "\n${YELLOW}Disque:${NC}"
    case $PLATFORM in
        "macos")
            df -h / | awk 'NR==2 {printf "  Total: %s, Utilisé: %s, Disponible: %s\n", $2, $3, $4}'
            ;;
        *)
            df -h / | awk 'NR==2 {printf "  Total: %s, Utilisé: %s, Disponible: %s\n", $2, $3, $4}'
            ;;
    esac
    
    # Température CPU
    log_result "\n${YELLOW}Température:${NC}"
    log_result "  CPU: $(get_cpu_temp)"
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

# Fonction pour formater les tableaux
format_table() {
    local title=$1
    shift
    local metrics=("$@")
    
    # Définir les largeurs fixes (encore augmentées)
    local name_width=35
    local value_width=60
    
    # Couleurs pour le tableau
    local title_bg=$BLUE
    local name_color=$YELLOW
    local value_color=$GREEN
    local border_color=$CYAN
    
    # Symboles pour les bordures (ASCII standard)
    local top_left="+"
    local top_right="+"
    local bottom_left="+"
    local bottom_right="+"
    local horizontal="-"
    local vertical="|"
    local cross="+"
    
    # Largeur totale du tableau
    local table_width=$((name_width + value_width + 3))
    
    # Titre du tableau avec fond coloré
    printf "${title_bg}%${table_width}s${NC}\n" " "
    printf "${title_bg}%-${table_width}s${NC}\n" "  $title"
    printf "${title_bg}%${table_width}s${NC}\n" " "
    
    # Ligne séparatrice supérieure
    printf "${border_color}%s" "$top_left"
    for ((i=0; i<name_width; i++)); do 
        printf "%s" "$horizontal"
    done
    printf "%s" "$cross"
    for ((i=0; i<value_width; i++)); do 
        printf "%s" "$horizontal"
    done
    printf "%s${NC}\n" "$top_right"
    
    # Afficher les données
    for metric in "${metrics[@]}"; do
        local name=$(echo "$metric" | cut -d':' -f1)
        local value=$(echo "$metric" | cut -d':' -f2-)
        # Supprimer les espaces en début et fin de la valeur
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        printf "${border_color}%s${name_color}%-${name_width}s${border_color}%s${value_color}%${value_width}s${border_color}%s${NC}\n" \
               "$vertical" " $name" "$vertical" " $value" "$vertical"
    done
    
    # Ligne séparatrice finale
    printf "${border_color}%s" "$bottom_left"
    for ((i=0; i<name_width; i++)); do 
        printf "%s" "$horizontal"
    done
    printf "%s" "$cross"
    for ((i=0; i<value_width; i++)); do 
        printf "%s" "$horizontal"
    done
    printf "%s${NC}\n\n" "$bottom_right"
}

# Fonction pour le benchmark CPU
benchmark_cpu() {
    log_result "\n${BLUE}=== BENCHMARK CPU ===${NC}"
    
    case $PLATFORM in
        "macos")
            # Test single-thread avec sysctl
            local cpu_brand=$(sysctl -n machdep.cpu.brand_string)
            local cpu_cores=$(sysctl -n hw.ncpu)
            local cpu_freq=$(sysctl -n hw.cpufrequency)
            
            # Test de performance avec dd
            local temp_file=$(mktemp)
            local start_time=$(date +%s.%N)
            dd if=/dev/zero of="$temp_file" bs=1M count=1000 2>/dev/null
            local end_time=$(date +%s.%N)
            local write_speed=$(echo "scale=2; 1000 / ($end_time - $start_time)" | bc)
            rm "$temp_file"
            
            # Formatage pour assurer un alignement parfait - Traitement exact du modèle
            # Stockage de chaque élément dans une variable intermédiaire
            local model="$cpu_brand"
            local freq_ghz=$(printf "%.2f GHz" "$(echo "scale=2; $cpu_freq/1000000000" | bc)")
            local speed_mb=$(printf "%.2f MB/s" "$write_speed")
            
            # Préparer les données pour le tableau avec plus d'espace et alignement contrôlé
            local metrics=(
                "Modèle CPU:$model"
                "Fréquence:$freq_ghz"
                "Vitesse d'écriture:$speed_mb"
            )
            
            format_table "Résultats CPU" "${metrics[@]}"
            ;;
        *)
            # Test standard pour Linux
            local results=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>/dev/null)
            local events=$(echo "$results" | grep 'total number of events:' | awk '{print $NF}')
            local time=$(echo "$results" | grep 'total time:' | awk '{print $NF}' | sed 's/s$//')
            local ops=$(echo "$results" | grep 'events per second:' | awk '{print $NF}')
            
            # Formatage pour assurer un alignement parfait - Traitement explicite
            local events_value=$(printf "%d" "${events:-0}")
            local time_value=$(printf "%.2f sec" "$(format_number "$time")")
            local ops_value=$(printf "%.2f" "$(format_number "$ops")")
            
            # Préparer les données pour le tableau
            local metrics=(
                "Événements:$events_value"
                "Temps total:$time_value"
                "Opérations/sec:$ops_value"
            )
            
            format_table "Résultats CPU" "${metrics[@]}"
            ;;
    esac
}

# Fonction pour le benchmark threads
benchmark_threads() {
    log_result "\n${BLUE}=== BENCHMARK THREADS ===${NC}"
    
    local cpu_cores=$(get_cpu_cores)
    local results=$(sysbench threads --threads=$cpu_cores --thread-yields=1000 --thread-locks=8 run 2>/dev/null)
    local time=$(echo "$results" | grep 'total time:' | awk '{print $NF}' | sed 's/s$//')
    local ops=$(echo "$results" | grep 'total number of events:' | awk '{print $NF}')
    local latency=$(echo "$results" | grep 'avg:' | awk '{print $NF}' | sed 's/ms$//')
    
    # Préparer les données pour le tableau
    local metrics=(
        "Temps d'exécution:$(printf "%.2f sec" "$(format_number "$time")")"
        "Opérations totales:$(printf "%d" "${ops:-0}")"
        "Latence moyenne:$(printf "%.2f ms" "$(format_number "$latency")")"
    )
    
    format_table "Résultats Threads" "${metrics[@]}"
}

# Fonction pour le benchmark mémoire
benchmark_memory() {
    log_result "\n${BLUE}=== BENCHMARK MÉMOIRE ===${NC}"
    
    case $PLATFORM in
        "macos")
            # Utiliser vm_stat et top pour macOS
            local total_memory=$(sysctl -n hw.memsize)
            local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
            local free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
            local active_pages=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
            local used_memory=$(( (active_pages * page_size) / 1024 / 1024 ))
            local free_memory=$(( (free_pages * page_size) / 1024 / 1024 ))
            
            # Test de performance avec dd
            local temp_file=$(mktemp)
            local start_time=$(date +%s.%N)
            dd if=/dev/zero of="$temp_file" bs=1M count=1000 2>/dev/null
            local end_time=$(date +%s.%N)
            local write_speed=$(echo "scale=2; 1000 / ($end_time - $start_time)" | bc)
            rm "$temp_file"
            
            # Préparer les données pour le tableau
            local metrics=(
                "Mémoire totale:$(printf "%.2f GB" "$(echo "scale=2; $total_memory/1024/1024/1024" | bc)")"
                "Mémoire utilisée:$(printf "%d MB" "$used_memory")"
                "Mémoire libre:$(printf "%d MB" "$free_memory")"
                "Vitesse d'écriture:$(printf "%.2f MB/s" "$write_speed")"
            )
            
            format_table "Résultats Mémoire" "${metrics[@]}"
            ;;
        *)
            # Test standard pour Linux
            local results=$(sysbench memory --memory-block-size=1K --memory-total-size=10G --memory-access-mode=seq run 2>/dev/null)
            local total_ops=$(echo "$results" | grep 'Total operations:' | awk '{print $NF}' | sed 's/[^0-9]//g')
            local total_transferred=$(echo "$results" | grep 'Total transferred' | awk '{print $3}')
            local transfer_speed=$(echo "$results" | grep 'transferred' | grep -o '[0-9.]\+ MiB/sec' | awk '{print $1}')
            
            # Préparer les données pour le tableau
            local metrics=(
                "Opérations totales:$(printf "%d" "$total_ops")"
                "Total transféré:$(printf "%s MiB" "$total_transferred")"
                "Vitesse de transfert:$(printf "%.2f MiB/sec" "$transfer_speed")"
            )
            
            format_table "Résultats Mémoire" "${metrics[@]}"
            ;;
    esac
}

# Fonction pour le benchmark disque
benchmark_disk() {
    log_result "\n${BLUE}=== BENCHMARK DISQUE ===${NC}"
    
    case $PLATFORM in
        "macos")
            # Utiliser diskutil et dd pour macOS
            local disk_info=$(diskutil info / | grep "Device Node\|Volume Name\|File System\|Total Size\|Free Space")
            local total_size=$(echo "$disk_info" | grep "Total Size" | awk '{print $3,$4}')
            local free_space=$(echo "$disk_info" | grep "Free Space" | awk '{print $3,$4}')
            
            # Test de performance avec dd
            local temp_file=$(mktemp)
            
            # Test d'écriture
            local start_time=$(date +%s.%N)
            dd if=/dev/zero of="$temp_file" bs=1M count=1000 2>/dev/null
            local end_time=$(date +%s.%N)
            local write_speed=$(echo "scale=2; 1000 / ($end_time - $start_time)" | bc)
            
            # Test de lecture
            local start_time=$(date +%s.%N)
            dd if="$temp_file" of=/dev/null bs=1M count=1000 2>/dev/null
            local end_time=$(date +%s.%N)
            local read_speed=$(echo "scale=2; 1000 / ($end_time - $start_time)" | bc)
            
            rm "$temp_file"
            
            # Affichage formaté avec les unités de manière cohérente
            if [[ -z "$total_size" ]]; then
                total_size="N/A"
            fi
            
            if [[ -z "$free_space" ]]; then
                free_space="N/A"
            fi
            
            # Préparer les données pour le tableau
            local metrics=(
                "Taille totale:$total_size"
                "Espace libre:$free_space"
                "Vitesse d'écriture:$(printf "%.2f MB/s" "$write_speed")"
                "Vitesse de lecture:$(printf "%.2f MB/s" "$read_speed")"
            )
            
            format_table "Résultats Disque" "${metrics[@]}"
            ;;
        *)
            # Test standard pour Linux
            local test_dir="/tmp/disk_benchmark"
            mkdir -p "$test_dir"
            cd "$test_dir"
            
            # Obtenir les informations sur l'espace disque
            local df_output=$(df -h / | awk 'NR==2 {print $2,$3,$4}')
            local total_size=$(echo "$df_output" | awk '{print $1}')
            local used_space=$(echo "$df_output" | awk '{print $2}')
            local free_space=$(echo "$df_output" | awk '{print $3}')
            
            sysbench fileio --file-total-size=2G prepare >/dev/null 2>&1
            local results=$(sysbench fileio --file-total-size=2G --file-test-mode=seqwr run 2>/dev/null)
            local write_speed=$(echo "$results" | grep 'written, MiB/s:' | awk '{print $NF}')
            local write_iops=$(echo "$results" | grep 'writes/s:' | awk '{print $NF}')
            
            results=$(sysbench fileio --file-total-size=2G --file-test-mode=seqrd run 2>/dev/null)
            local read_speed=$(echo "$results" | grep 'read, MiB/s:' | awk '{print $NF}')
            local read_iops=$(echo "$results" | grep 'reads/s:' | awk '{print $NF}')
            
            # Préparer les données pour le tableau avec les unités
            local metrics=(
                "Taille totale:$(printf "%s" "$total_size")"
                "Espace utilisé:$(printf "%s" "$used_space")"
                "Espace libre:$(printf "%s" "$free_space")"
                "Vitesse d'écriture:$(printf "%.2f MB/s" "${write_speed:-0}")"
                "IOPS en écriture:$(printf "%.2f" "${write_iops:-0}")"
                "Vitesse de lecture:$(printf "%.2f MB/s" "${read_speed:-0}")"
                "IOPS en lecture:$(printf "%.2f" "${read_iops:-0}")"
            )
            
            format_table "Résultats Disque" "${metrics[@]}"
            
            # Nettoyage
            sysbench fileio cleanup >/dev/null 2>&1
            cd - >/dev/null
            rm -rf "$test_dir"
            ;;
    esac
}

# Fonction pour le benchmark réseau
benchmark_network() {
    log_result "\n${BLUE}=== BENCHMARK RÉSEAU ===${NC}"
    
    case $PLATFORM in
        "macos")
            # Test de latence avec plusieurs serveurs
            local ping_servers=("8.8.8.8" "1.1.1.1" "208.67.222.222")
            local total_ping=0
            local ping_count=0
            
            for server in "${ping_servers[@]}"; do
                local ping_result=$(ping -c 5 "$server" 2>/dev/null | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
                if [ -n "$ping_result" ] && [ "$ping_result" != "0" ]; then
                    total_ping=$(echo "$total_ping + $ping_result" | bc)
                    ping_count=$((ping_count + 1))
                fi
            done
            
            local avg_ping=0
            if [ $ping_count -gt 0 ]; then
                avg_ping=$(echo "scale=2; $total_ping / $ping_count" | bc)
            fi
            
            # Test de débit
            local download_speed=0
            local upload_speed=0
            
            if command -v networkQuality &> /dev/null; then
                local result=$(networkQuality -v)
                download_speed=$(echo "$result" | grep "Download capacity" | awk '{print $3}')
                upload_speed=$(echo "$result" | grep "Upload capacity" | awk '{print $3}')
            elif command -v speedtest-cli &> /dev/null; then
                local result=$(speedtest-cli --simple)
                download_speed=$(echo "$result" | grep "Download" | awk '{print $2}')
                upload_speed=$(echo "$result" | grep "Upload" | awk '{print $2}')
            fi
            
            # Préparer les données pour le tableau
            local metrics=(
                "Latence moyenne:$(printf "%.2f ms" "${avg_ping:-0}")"
                "Débit descendant:$(printf "%.2f Mbps" "${download_speed:-0}")"
                "Débit montant:$(printf "%.2f Mbps" "${upload_speed:-0}")"
            )
            
            format_table "Résultats Réseau" "${metrics[@]}"
            ;;
        *)
            # Test standard pour Linux
            # ... reste du code existant ...
            ;;
    esac
}

# Fonction pour le stress test et monitoring température
stress_test() {
    log_result "\n${BLUE}=== STRESS TEST ET MONITORING TEMPÉRATURE ===${NC}"
    
    echo -n "Entrez la durée du stress test en secondes (défaut: 60): "
    read -r duration
    duration=${duration:-60}
    
    local cpu_cores=$(get_cpu_cores)
    
    log_result "${YELLOW}Démarrage du stress test pour $duration secondes...${NC}"
    log_result "  Nombre de threads: $cpu_cores"
    log_result "  Température initiale: $(get_cpu_temp)"
    
    # Démarrer le stress test en arrière-plan
    stress-ng --cpu $cpu_cores --timeout "${duration}s" &
    local stress_pid=$!
    
    # Monitoring de la température
    local interval=5
    local elapsed_time=0
    
    while [ $elapsed_time -lt $duration ]; do
        sleep $interval
        elapsed_time=$((elapsed_time + interval))
        local temp=$(get_cpu_temp)
        
        case $PLATFORM in
            "raspbian")
                if (( $(echo "$temp" | sed 's/°C//' | awk '{if ($1 > '$TEMP_THRESHOLD') print 1; else print 0}') )); then
                    log_result "${RED}ALERTE: Température CPU élevée: ${temp}${NC}"
                else
                    log_result "  Temps écoulé: $elapsed_time secondes | Température CPU: ${temp}"
                fi
                ;;
            *)
                log_result "  Temps écoulé: $elapsed_time secondes | Température CPU: ${temp}"
                ;;
        esac
    done
    
    # Attendre la fin du stress test
    wait $stress_pid 2>/dev/null || true
    
    log_result "${GREEN}Stress test terminé${NC}"
    log_result "  Température finale: $(get_cpu_temp)"
}

# Fonction pour envoyer les résultats à Plotly
send_to_plotly() {
    local results_file="$RESULTS_DIR/benchmark_results_$(date +%Y%m%d_%H%M%S).json"
    
    # Créer un fichier JSON avec les résultats
    cat > "$results_file" << EOF
{
    "date": "$(date +%Y-%m-%dT%H:%M:%S)",
    "cpu_single_thread": {
        "events": "$(echo "$results" | grep 'single-thread' -A 4 | grep 'Événements' | awk '{print $NF}')",
        "ops_per_sec": "$(echo "$results" | grep 'single-thread' -A 4 | grep 'Opérations/sec' | awk '{print $NF}')"
    },
    "cpu_multi_thread": {
        "events": "$(echo "$results" | grep 'multi-thread' -A 4 | grep 'Événements' | awk '{print $NF}')",
        "ops_per_sec": "$(echo "$results" | grep 'multi-thread' -A 4 | grep 'Opérations/sec' | awk '{print $NF}')"
    },
    "memory": {
        "transfer_speed": "$(echo "$results" | grep 'Vitesse de transfert' | awk '{print $NF}' | sed 's/MiB\/sec//')"
    },
    "disk": {
        "write_speed": "$(echo "$results" | grep 'Vitesse d.écriture' | awk '{print $NF}' | sed 's/MB\/s//')",
        "read_speed": "$(echo "$results" | grep 'Vitesse de lecture' | awk '{print $NF}' | sed 's/MB\/s//')"
    },
    "network": {
        "download_speed": "$(echo "$results" | grep 'Débit descendant' | awk '{print $NF}' | sed 's/Mbps//')",
        "ping": "$(echo "$results" | grep 'Latence moyenne' | awk '{print $NF}' | sed 's/ms//')"
    }
}
EOF

    # Envoyer les données à Plotly
    if command -v curl &> /dev/null; then
        local plotly_url=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d @"$results_file" \
            "https://api.plot.ly/v2/plots" \
            | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$plotly_url" ]; then
            echo -e "${GREEN}Graphiques disponibles à l'adresse : ${plotly_url}${NC}"
            echo "URL des graphiques : $plotly_url" >> "$LOG_FILE"
        else
            echo -e "${RED}Erreur lors de l'envoi des données à Plotly${NC}"
        fi
    else
        echo -e "${RED}curl n'est pas installé. Impossible d'envoyer les données à Plotly.${NC}"
    fi
}

# Fonction pour générer les graphiques avec Chart.js
generate_charts() {
    local html_file="$RESULTS_DIR/benchmark_charts.html"
    
    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RPi Benchmark Results</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .chart-container { width: 80%; margin: 20px auto; }
    </style>
</head>
<body>
    <h1>RPi Benchmark Results</h1>
    <div class="chart-container">
        <canvas id="cpuChart"></canvas>
    </div>
    <div class="chart-container">
        <canvas id="memoryChart"></canvas>
    </div>
    <div class="chart-container">
        <canvas id="diskChart"></canvas>
    </div>
    <div class="chart-container">
        <canvas id="networkChart"></canvas>
    </div>
    <script>
        // Données du benchmark
        const data = {
            cpu: {
                singleThread: {
                    events: 32310206,
                    opsPerSec: 3230563.48
                },
                multiThread: {
                    events: 217043164,
                    opsPerSec: 21701265.20
                }
            },
            memory: {
                transferSpeed: 2562.22
            },
            disk: {
                writeSpeed: 246.38,
                readSpeed: 1002.24,
                writeIOPS: 15768.56,
                readIOPS: 64143.05
            },
            network: {
                downloadSpeed: 0,
                ping: 45.272
            }
        };

        // Graphique CPU
        new Chart(document.getElementById('cpuChart'), {
            type: 'bar',
            data: {
                labels: ['Single Thread', 'Multi Thread'],
                datasets: [{
                    label: 'Opérations par seconde',
                    data: [data.cpu.singleThread.opsPerSec, data.cpu.multiThread.opsPerSec],
                    backgroundColor: ['rgba(54, 162, 235, 0.5)', 'rgba(255, 99, 132, 0.5)']
                }]
            },
            options: {
                responsive: true,
                title: {
                    display: true,
                    text: 'Performance CPU'
                }
            }
        });

        // Graphique Mémoire
        new Chart(document.getElementById('memoryChart'), {
            type: 'doughnut',
            data: {
                labels: ['Vitesse de transfert'],
                datasets: [{
                    data: [data.memory.transferSpeed],
                    backgroundColor: ['rgba(75, 192, 192, 0.5)']
                }]
            },
            options: {
                responsive: true,
                title: {
                    display: true,
                    text: 'Performance Mémoire'
                }
            }
        });

        // Graphique Disque
        new Chart(document.getElementById('diskChart'), {
            type: 'bar',
            data: {
                labels: ['Écriture', 'Lecture'],
                datasets: [{
                    label: 'Vitesse (MB/s)',
                    data: [data.disk.writeSpeed, data.disk.readSpeed],
                    backgroundColor: ['rgba(255, 206, 86, 0.5)', 'rgba(75, 192, 192, 0.5)']
                }]
            },
            options: {
                responsive: true,
                title: {
                    display: true,
                    text: 'Performance Disque'
                }
            }
        });

        // Graphique Réseau
        new Chart(document.getElementById('networkChart'), {
            type: 'line',
            data: {
                labels: ['Latence', 'Débit'],
                datasets: [{
                    label: 'Performance',
                    data: [data.network.ping, data.network.downloadSpeed],
                    backgroundColor: ['rgba(153, 102, 255, 0.5)']
                }]
            },
            options: {
                responsive: true,
                title: {
                    display: true,
                    text: 'Performance Réseau'
                }
            }
        });
    </script>
</body>
</html>
EOF

    echo -e "${GREEN}Graphiques générés dans : $html_file${NC}"
    echo -e "${YELLOW}Ouvrez le fichier dans votre navigateur pour voir les graphiques.${NC}"
}

# Fonction pour modifier run_all_benchmarks pour inclure la génération des graphiques
run_all_benchmarks() {
    benchmark_cpu
    benchmark_threads
    benchmark_memory
    benchmark_disk
    benchmark_network
    generate_charts
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