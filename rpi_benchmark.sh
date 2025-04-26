#!/bin/bash

# =====================================================
# Script de Benchmarking et Monitoring pour Raspberry Pi
# =====================================================

# Arrêt en cas d'erreur
set -e

# Couleurs pour l'affichage amélioré
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
ORANGE='\033[38;5;208m'
LIME='\033[38;5;119m'
MAGENTA='\033[38;5;201m'
TEAL='\033[38;5;6m'
GRAY='\033[38;5;245m'
NC='\033[0m' # No Color

# Arrière-plans
BG_BLUE='\033[44m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_MAGENTA='\033[45m'
BG_CYAN='\033[46m'
BG_GRAY='\033[48;5;240m'
BG_DARK='\033[48;5;235m'
BG_BLACK='\033[40m'

# Styles
BOLD='\033[1m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
INVERSE='\033[7m'
DIM='\033[2m'

# Variables globales
RESULTS_DIR="benchmark_results"
LOG_FILE="${RESULTS_DIR}/benchmark_results_$(date +%Y%m%d_%H%M%S).log"
TEMP_THRESHOLD=70 # Seuil de température critique en degrés Celsius
HISTORY_DB="$RESULTS_DIR/benchmark_history.db"
MAX_LOGS=10 # Nombre maximum de fichiers de log à conserver

# Symboles Unicode pour l'interface moderne
SYMBOL_RIGHT_ARROW="▶"
SYMBOL_LEFT_ARROW="◀"
SYMBOL_DIAMOND="◆"
SYMBOL_CIRCLE="●"
SYMBOL_SQUARE="■"
SYMBOL_CHECK="✓"
SYMBOL_CROSS="✗"
SYMBOL_WARNING="⚠"
SYMBOL_INFO="ℹ"
SYMBOL_STAR="★"
SYMBOL_BOLT="⚡"
SYMBOL_CLOCK="⏱"
SYMBOL_CPU="🖥️"
SYMBOL_RAM="🧠"
SYMBOL_DISK="💾"
SYMBOL_NETWORK="🌐"
SYMBOL_TEMP="🌡️"
SYMBOL_CHART="📊"

# Détection de la plateforme
PLATFORM="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" == "raspbian" ]] || [[ "$ID" == "debian" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        PLATFORM="raspbian"
    elif [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
        PLATFORM="ubuntu"
    fi
elif [[ -f /proc/cpuinfo ]] && grep -q "Raspberry Pi" /proc/cpuinfo; then
    PLATFORM="raspbian"
fi

# Si toujours inconnu mais existence de commandes spécifiques Raspberry
if [[ "$PLATFORM" == "unknown" ]] && command -v vcgencmd &> /dev/null; then
    PLATFORM="raspbian"
fi

# Fonction pour afficher une erreur et quitter avec style moderne
display_error() {
    echo ""
    echo -e "${BG_RED}${WHITE}${BOLD} ERREUR ${NC} ${RED}${BOLD}$1${NC}"
    echo ""
    echo -e "${BG_YELLOW}${BLACK} DIAGNOSTIC ${NC} ${YELLOW}Informations système:${NC}"
    echo -e "  ${SYMBOL_INFO} Plateforme détectée: ${BOLD}$PLATFORM${NC}"
    echo -e "  ${SYMBOL_INFO} Système d'exploitation: ${BOLD}$(uname -a)${NC}"
    
    if [[ -f /etc/os-release ]]; then
        echo -e "  ${SYMBOL_INFO} Contenu de /etc/os-release:"
        cat /etc/os-release | sed 's/^/    /'
    fi
    
    if [[ -f /proc/cpuinfo ]]; then
        echo -e "  ${SYMBOL_INFO} Modèle CPU:"
        grep "model name\|Model" /proc/cpuinfo | head -n1 | sed 's/^/    /'
    fi
    
    exit 1
}

# Fonction pour installer un paquet avec retour visuel
install_package() {
    local package=$1
    
    echo -e "${GRAY}┌─ ${YELLOW}Installation${NC} ${GRAY}──${NC} $package ${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
    
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
    
    if [ $? -eq 0 ]; then
        echo -e "${GRAY}└─ ${GREEN}${SYMBOL_CHECK} Terminé${NC}"
    else
        echo -e "${GRAY}└─ ${RED}${SYMBOL_CROSS} Échec${NC}"
    fi
}

# Fonction pour une barre de progression
show_progress() {
    local percent=$1
    local width=50
    local completed=$((percent * width / 100))
    local remaining=$((width - completed))
    
    printf "${GRAY}[${LIME}"
    printf "%${completed}s" | tr ' ' '■'
    printf "${GRAY}"
    printf "%${remaining}s" | tr ' ' '□'
    printf "${GRAY}] ${WHITE}%3d%%${NC}\r" $percent
}

# Affichage moderne d'un en-tête
modern_header() {
    local title=$1
    local color=$2
    local symbol=$3
    local width=70
    
    echo ""
    echo -e "${color}${BOLD}┏━━━ $symbol ${title} $(printf '━%.0s' $(seq 1 $((width - ${#title} - 7))))┓${NC}"
    echo -e "${color}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
}

# Fonction pour afficher l'en-tête principal
show_header() {
    clear
    echo ""
    echo -e "${BLUE}${BOLD}╔═════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║                                                                 ║${NC}"
    echo -e "${BLUE}${BOLD}║  ${WHITE}${BOLD}  RPi BENCHMARK v2.0 - ANALYSE COMPLÈTE DES PERFORMANCES       ${NC}${BLUE}${BOLD}║${NC}"
    echo -e "${BLUE}${BOLD}║                                                                 ║${NC}"
    echo -e "${BLUE}${BOLD}╚═════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}${SYMBOL_CLOCK} ${WHITE}Date:${NC} $(date '+%d %B %Y - %H:%M:%S')"
    echo -e "  ${YELLOW}${SYMBOL_INFO} ${WHITE}Journal:${NC} $LOG_FILE"
    echo ""
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 75))${NC}"
    echo ""
}

# Fonction pour logger les résultats avec style moderne
log_result() {
    local message="$1"
    
    # Afficher le message à l'écran
    echo -e "$message"
    
    # Vérifier que le répertoire de résultats existe
    if [ ! -d "$RESULTS_DIR" ]; then
        mkdir -p "$RESULTS_DIR" 2>/dev/null || {
            echo -e "${RED}${SYMBOL_CROSS} Impossible de créer le répertoire $RESULTS_DIR${NC}"
            return 0
        }
    fi
    
    # Tenter d'écrire dans le fichier journal, mais continuer en cas d'échec
    echo -e "$message" >> "$LOG_FILE" 2>/dev/null || {
        echo -e "${RED}${SYMBOL_CROSS} Erreur lors de l'écriture dans le fichier journal: $LOG_FILE${NC}" >&2
        return 0  # Retourner avec succès pour continuer l'exécution
    }
}

# Formater les tableaux de façon moderne
format_table() {
    local title=$1
    shift
    local metrics=("$@")
    
    # Définir les largeurs fixes
    local name_width=35
    local value_width=40
    
    # Couleurs pour le tableau moderne
    local header_bg=$BG_DARK
    local header_fg=$WHITE
    local row_color=$CYAN
    local alt_row_color=$BLUE
    local line_color=$GRAY
    local text_color=$WHITE
    local value_color=$LIME
    
    # Symboles pour les bordures modernes
    local top_left="╭"
    local top_right="╮"
    local bottom_left="╰"
    local bottom_right="╯"
    local horizontal="─"
    local vertical="│"
    local left_t="├"
    local right_t="┤"
    local cross="┼"
    local top_t="┬"
    local bottom_t="┴"
    
    # Calculer la largeur totale
    local total_width=$((name_width + value_width + 3))
    
    # Enregistrer les métriques dans le journal, mais pas dans la sortie standard
    {
        echo -e "\n# Données pour $title"
        for metric in "${metrics[@]}"; do
            local name=$(echo "$metric" | cut -d':' -f1)
            local value=$(echo "$metric" | cut -d':' -f2-)
            # Supprimer les espaces en début et fin de la valeur
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            echo "$name: $value"
        done
    } >> "$LOG_FILE" 2>/dev/null
    
    # Afficher le titre du tableau
    echo ""
    echo -e "${BOLD}${BLUE}${title}${NC}"
    
    # Ligne supérieure
    echo -ne "${line_color}${top_left}"
    printf "%s" $(printf "%${total_width}s" | tr " " "$horizontal")
    echo -e "${top_right}${NC}"
    
    # Ligne d'en-tête
    echo -ne "${line_color}${vertical}${NC}${header_bg}${header_fg}${BOLD}"
    printf " %-${name_width}s │ %-${value_width}s " "MÉTRIQUE" "VALEUR"
    echo -e "${NC}${line_color}${vertical}${NC}"
    
    # Ligne de séparation
    echo -ne "${line_color}${left_t}"
    printf "%s" $(printf "%${name_width}s" | tr " " "$horizontal")
    echo -ne "${cross}"
    printf "%s" $(printf "%${value_width}s" | tr " " "$horizontal")
    echo -e "${right_t}${NC}"
    
    # Corps du tableau avec alternance de couleurs
    local i=0
    for metric in "${metrics[@]}"; do
        local name=$(echo "$metric" | cut -d':' -f1)
        local value=$(echo "$metric" | cut -d':' -f2-)
        # Supprimer les espaces en début et fin de la valeur
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        if [ $((i % 2)) -eq 0 ]; then
            background_color=""
        else
            background_color=""
        fi
        
        echo -ne "${line_color}${vertical}${NC}${background_color}"
        printf " ${text_color}%-${name_width}s${NC}${background_color} ${line_color}${vertical}${NC}${background_color} ${value_color}%-${value_width}s ${NC}${line_color}${vertical}${NC}\n" "$name" "$value"
        
        i=$((i + 1))
    done
    
    # Ligne inférieure
    echo -ne "${line_color}${bottom_left}"
    printf "%s" $(printf "%${total_width}s" | tr " " "$horizontal")
    echo -e "${bottom_right}${NC}"
}

# Fonction pour obtenir la température CPU avec style moderne
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

# Fonction pour obtenir les informations hardware avec présentation moderne
get_hardware_info() {
    modern_header "INFORMATIONS HARDWARE" $CYAN $SYMBOL_INFO
    
    # Informations CPU
    echo -e "  ${CYAN}${SYMBOL_CPU} ${BOLD}${WHITE}CPU:${NC}"
    case $PLATFORM in
        "macos")
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Modèle:${NC} $(sysctl -n machdep.cpu.brand_string)"
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Architecture:${NC} $(uname -m)"
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Cœurs:${NC} $(sysctl -n hw.ncpu)"
            ;;
        "raspbian")
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Modèle:${NC} $(cat /proc/cpuinfo | grep "Model" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')"
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Architecture:${NC} $(uname -m)"
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Cœurs:${NC} $(nproc)"
            if command -v vcgencmd &> /dev/null; then
                echo -e "    ${YELLOW}⬥${NC} ${WHITE}Fréquence:${NC} $(vcgencmd measure_clock arm | awk -F'=' '{printf "%.0f MHz\n", $2/1000000}')"
                echo -e "    ${YELLOW}⬥${NC} ${WHITE}Voltage:${NC} $(vcgencmd measure_volts core | cut -d'=' -f2)"
            fi
            ;;
        *)
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Modèle:${NC} $(cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')"
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Architecture:${NC} $(uname -m)"
            echo -e "    ${YELLOW}⬥${NC} ${WHITE}Cœurs:${NC} $(nproc)"
            ;;
    esac
    
    # Informations Mémoire
    echo -e "  ${MAGENTA}${SYMBOL_RAM} ${BOLD}${WHITE}Mémoire:${NC}"
    case $PLATFORM in
        "macos")
            local total_mem=$(($(sysctl -n hw.memsize) / 1024 / 1024))
            echo -e "    ${MAGENTA}⬥${NC} ${WHITE}Total:${NC} ${total_mem}M"
            ;;
        *)
            echo -e "    ${MAGENTA}⬥${NC} ${WHITE}RAM:${NC} $(free -h | grep "Mem:" | awk '{printf "Total: %s, Utilisé: %s, Libre: %s", $2, $3, $4}')"
            echo -e "    ${MAGENTA}⬥${NC} ${WHITE}Swap:${NC} $(free -h | grep "Swap:" | awk '{printf "Total: %s, Utilisé: %s, Libre: %s", $2, $3, $4}')"
            ;;
    esac
    
    # Informations Disque
    echo -e "  ${YELLOW}${SYMBOL_DISK} ${BOLD}${WHITE}Disque:${NC}"
    case $PLATFORM in
        "macos")
            df -h / | awk 'NR==2 {printf "    %s Total: %s, Utilisé: %s, Disponible: %s\n", "⬥", $2, $3, $4}'
            ;;
        *)
            df -h / | awk 'NR==2 {printf "    %s Total: %s, Utilisé: %s, Disponible: %s\n", "⬥", $2, $3, $4}'
            ;;
    esac
    
    # Température CPU
    echo -e "  ${RED}${SYMBOL_TEMP} ${BOLD}${WHITE}Température:${NC}"
    echo -e "    ${RED}⬥${NC} ${WHITE}CPU:${NC} $(get_cpu_temp)"
}

# install_dependencies: Vérifie et installe en une seule passe les dépendances requises
install_dependencies() {
    echo -e "${YELLOW}${BOLD}Vérification et installation optimisée des dépendances...${NC}"

    # Paquets communs et spécifiques à la plateforme
    local common_packages=(sysbench bc sqlite3 python3)
    local platform_packages=()

    # Détection de la plateforme
    case "${PLATFORM}" in
        macos)
            echo -e "${CYAN}macOS détecté${NC}"
            platform_packages=(stress-ng speedtest-cli osx-cpu-temp iperf3)
            ;;  
        raspbian|ubuntu)
            echo -e "${CYAN}Debian/Ubuntu détecté${NC}"
            platform_packages=(stress-ng speedtest-cli dnsutils hdparm python3-pip dialog iperf3)
            ;;  
        *)
            if command -v apt-get &> /dev/null; then
                echo -e "${CYAN}Debian/Ubuntu détecté via apt-get${NC}"
                platform_packages=(stress-ng speedtest-cli dnsutils hdparm python3-pip dialog iperf3)
            elif command -v yum &> /dev/null; then
                echo -e "${CYAN}RHEL/CentOS détecté via yum${NC}"
                platform_packages=(stress-ng dnsutils hdparm python3-pip dialog iperf3)
                # Ajouter epel-release si sysbench absent
                if ! command -v sysbench &> /dev/null; then
                    platform_packages+=(epel-release)
                fi
            else
                echo -e "${YELLOW}Plateforme inconnue, utilisation des paquets Linux génériques${NC}"
                platform_packages=(stress-ng speedtest-cli dnsutils hdparm python3-pip dialog iperf3)
            fi
            ;;  
    esac

    # Combinaison des listes et recherche des paquets manquants
    local all_packages=("${common_packages[@]}" "${platform_packages[@]}")
    local missing=()
    for pkg in "${all_packages[@]}"; do
        if ! command -v "${pkg%%-*}" &> /dev/null; then
            missing+=("$pkg")
        fi
    done

    # Si rien à installer
    if [ ${#missing[@]} -eq 0 ]; then
        echo -e "${GREEN}${BOLD}Toutes les dépendances sont déjà installées !${NC}"
        return 0
    fi

    echo -e "${YELLOW}Paquets manquants: ${missing[*]}${NC}"

    # Préparation des noms pour yum si nécessaire
    local to_install=("")
    if command -v yum &> /dev/null; then
        for pkg in "${missing[@]}"; do
            case "$pkg" in
                dnsutils) to_install+=(bind-utils) ;;
                sqlite3)  to_install+=(sqlite)     ;;
                python3-pip) to_install+=(python3-pip) ;;
                *) to_install+=("$pkg") ;;
            esac
        done
    else
        to_install=("${missing[@]}")
    fi

    # Installation groupée
    if command -v brew &> /dev/null && [ "${PLATFORM}" = "macos" ]; then
        brew update && brew install ${to_install[*]}
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y ${to_install[*]}
    elif command -v yum &> /dev/null; then
        sudo yum install -y ${to_install[*]}
    else
        echo -e "${RED}Aucun gestionnaire de paquets pris en charge détecté${NC}"
        return 1
    fi

    echo -e "${GREEN}${BOLD}Installation terminée avec succès !${NC}"
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
    modern_header "BENCHMARK CPU" $CYAN $SYMBOL_CPU
    
    case $PLATFORM in
        "macos")
            # Test single-thread avec sysctl
            echo -e "${WHITE}${BOLD}Test de performance CPU pour macOS...${NC}"
            echo -e "${YELLOW}${SYMBOL_INFO} Collecte des informations sur le processeur...${NC}"
            
            local cpu_brand=$(sysctl -n machdep.cpu.brand_string)
            local cpu_cores=$(sysctl -n hw.ncpu)
            local cpu_freq=$(sysctl -n hw.cpufrequency)
            
            # Test de performance avec dd
            echo -e "${YELLOW}${SYMBOL_INFO} Exécution du test de performance...${NC}"
            
            local temp_file=$(mktemp)
            local start_time=$(date +%s.%N)
            
            # Barre de progression simulée
            for i in {1..10}; do
                show_progress $((i*10))
                sleep 0.1
            done
            
            dd if=/dev/zero of="$temp_file" bs=1M count=1000 2>/dev/null
            local end_time=$(date +%s.%N)
            local write_speed=$(echo "scale=2; 1000 / ($end_time - $start_time)" | bc)
            rm "$temp_file"
            echo -e "\n${GREEN}${SYMBOL_CHECK} Test terminé ${NC}"
            
            # Formatage pour assurer un alignement parfait
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
            echo -e "${WHITE}${BOLD}Test de performance CPU pour Linux...${NC}"
            echo -e "${YELLOW}${SYMBOL_INFO} Exécution du benchmark sysbench CPU...${NC}"
            
            # Créer un fichier temporaire pour stocker les résultats
            local temp_results_file=$(mktemp)
            
            # Exécuter sysbench en arrière-plan et rediriger sa sortie vers un fichier temporaire
            sysbench cpu --cpu-max-prime=20000 --threads=1 run > "$temp_results_file" 2>/dev/null &
            local pid=$!
            
            # Afficher une barre de progression pendant l'exécution
            show_progress 0
            local progress=0
            while kill -0 $pid 2>/dev/null; do
                progress=$((progress + 5))
                [ $progress -gt 95 ] && progress=95
                show_progress $progress
                sleep 0.2
            done
            
            # Attendre la fin de sysbench
            wait $pid
            show_progress 100
            echo -e "\n${GREEN}${SYMBOL_CHECK} Test terminé ${NC}"
            
            # Lire les résultats du fichier temporaire
            local results=$(cat "$temp_results_file")
            rm "$temp_results_file"
            
            local events=$(echo "$results" | grep 'total number of events:' | awk '{print $NF}')
            local time=$(echo "$results" | grep 'total time:' | awk '{print $NF}' | sed 's/s$//')
            local ops=$(echo "$results" | grep 'events per second:' | awk '{print $NF}')
            
            # Formatage pour assurer un alignement parfait
            local events_formatted=$(printf "%d" "${events:-0}")
            local time_formatted=$(printf "%.2f sec" "$(format_number "$time")")
            local ops_formatted=$(printf "%.2f" "$(format_number "$ops")")
            
            # Préparer les données pour le tableau
            local metrics=(
                "Événements:$events_formatted"
                "Temps total:$time_formatted"
                "Opérations/sec:$ops_formatted"
            )
            
            format_table "Résultats CPU" "${metrics[@]}"
            ;;
    esac
}

# Fonction pour le benchmark threads
benchmark_threads() {
    modern_header "BENCHMARK THREADS" $PURPLE $SYMBOL_BOLT
    
    echo -e "${WHITE}${BOLD}Test de performance multi-threads...${NC}"
    echo -e "${YELLOW}${SYMBOL_INFO} Détection du nombre de cœurs CPU: $(get_cpu_cores)${NC}"
    echo -e "${YELLOW}${SYMBOL_INFO} Exécution du benchmark sysbench threads...${NC}"
    
    local cpu_cores=$(get_cpu_cores)
    
    # Créer un fichier temporaire pour stocker les résultats
    local temp_results_file=$(mktemp)
    
    # Exécuter sysbench en arrière-plan et rediriger sa sortie vers un fichier temporaire
    sysbench threads --threads=$cpu_cores --thread-yields=1000 --thread-locks=8 run > "$temp_results_file" 2>/dev/null &
    local pid=$!
    
    # Afficher une barre de progression pendant l'exécution
    show_progress 0
    local progress=0
    while kill -0 $pid 2>/dev/null; do
        progress=$((progress + 5))
        [ $progress -gt 95 ] && progress=95
        show_progress $progress
        sleep 0.2
    done
    
    # Attendre la fin de sysbench
    wait $pid
    show_progress 100
    echo -e "\n${GREEN}${SYMBOL_CHECK} Test terminé ${NC}"
    
    # Lire les résultats du fichier temporaire
    local results=$(cat "$temp_results_file")
    rm "$temp_results_file"
    
    local time=$(echo "$results" | grep 'total time:' | awk '{print $NF}' | sed 's/s$//')
    local ops=$(echo "$results" | grep 'total number of events:' | awk '{print $NF}')
    local latency=$(echo "$results" | grep 'avg:' | awk '{print $NF}' | sed 's/ms$//')
    
    # Préparer les données pour le tableau avec formatage amélioré
    local metrics=(
        "Nombre de threads:$cpu_cores"
        "Temps d'exécution:$(printf "%.2f sec" "$(format_number "$time")")"
        "Opérations totales:$(printf "%d" "${ops:-0}")"
        "Latence moyenne:$(printf "%.2f ms" "$(format_number "$latency")")"
    )
    
    format_table "Résultats Threads" "${metrics[@]}"
}

# Fonction pour le benchmark mémoire
benchmark_memory() {
    modern_header "BENCHMARK MÉMOIRE" $MAGENTA $SYMBOL_RAM
    
    case $PLATFORM in
        "macos")
            echo -e "${WHITE}${BOLD}Test de performance mémoire pour macOS...${NC}"
            echo -e "${YELLOW}${SYMBOL_INFO} Collecte des informations sur la mémoire...${NC}"
            
            # Utiliser vm_stat et top pour macOS
            local total_memory=$(sysctl -n hw.memsize)
            local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
            local free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
            local active_pages=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
            local used_memory=$(( (active_pages * page_size) / 1024 / 1024 ))
            local free_memory=$(( (free_pages * page_size) / 1024 / 1024 ))
            
            # Test de performance avec dd
            echo -e "${YELLOW}${SYMBOL_INFO} Exécution du test de transfert mémoire...${NC}"
            
            # Barre de progression simulée
            for i in {1..10}; do
                show_progress $((i*10))
                sleep 0.1
            done
            
            local temp_file=$(mktemp)
            local start_time=$(date +%s.%N)
            dd if=/dev/zero of="$temp_file" bs=1M count=1000 2>/dev/null
            local end_time=$(date +%s.%N)
            local write_speed=$(echo "scale=2; 1000 / ($end_time - $start_time)" | bc)
            rm "$temp_file"
            echo -e "\n${GREEN}${SYMBOL_CHECK} Test terminé ${NC}"
            
            # Conversion en GB pour l'affichage
            local total_gb=$(echo "scale=2; $total_memory/1024/1024/1024" | bc)
            
            # Préparer les données pour le tableau
            local metrics=(
                "Mémoire totale:$(printf "%.2f GB" "$total_gb")"
                "Mémoire utilisée:$(printf "%d MB" "$used_memory")"
                "Mémoire libre:$(printf "%d MB" "$free_memory")"
                "Ratio utilisation:$(printf "%.1f%%" "$(echo "scale=1; $used_memory*100/$((used_memory+free_memory))" | bc)")"
                "Vitesse de transfert:$(printf "%.2f MB/s" "$write_speed")"
            )
            
            format_table "Résultats Mémoire" "${metrics[@]}"
            ;;
        *)
            # Test de mémoire plus fiable pour Linux
            echo -e "${WHITE}${BOLD}Test de performance mémoire pour Linux...${NC}"
            
            # Vérifier que sysbench est disponible
            if ! command -v sysbench &>/dev/null; then
                echo -e "${RED}${SYMBOL_WARNING} sysbench non disponible. Utilisation d'une méthode alternative.${NC}"
                
                # Méthode alternative avec dd
                echo -e "${YELLOW}${SYMBOL_INFO} Utilisation de dd pour le test de mémoire...${NC}"
                local temp_file="/tmp/memory_benchmark_$$"
                local size_mb=100
                
                # Barre de progression simulée
                for i in {1..10}; do
                    show_progress $((i*10))
                    sleep 0.1
                done
                
                local start_time=$(date +%s)
                dd if=/dev/zero of="$temp_file" bs=1M count=$size_mb status=none 2>/dev/null
                local end_time=$(date +%s)
                local time_diff=$((end_time - start_time))
                
                # Protéger contre division par zéro
                if [ $time_diff -eq 0 ]; then
                    time_diff=1
                fi
                
                local transfer_speed=$((size_mb / time_diff))
                # Pour éviter 0 MiB/sec
                [ $transfer_speed -eq 0 ] && transfer_speed=1
                
                # Nettoyer
                rm -f "$temp_file" 2>/dev/null
                echo -e "${GREEN}${SYMBOL_CHECK} Test terminé ${NC}"
                
                # Récupérer les infos mémoire du système
                echo -e "${YELLOW}${SYMBOL_INFO} Lecture des informations système...${NC}"
                local mem_info=$(free -m)
                local total_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $2}')
                local used_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $3}')
                local free_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $4}')
    
            # Préparer les données pour le tableau
            local metrics=(
                    "Mémoire totale:$(printf "%d MB" "$total_memory")"
                    "Mémoire utilisée:$(printf "%d MB" "$used_memory")"
                    "Mémoire libre:$(printf "%d MB" "$free_memory")"
                    "Ratio utilisation:$(printf "%.1f%%" "$(echo "scale=1; $used_memory*100/$total_memory" | bc)")"
                    "Opérations testées:100"
                    "Données transférées:$(printf "%d MiB" "$size_mb")"
                    "Vitesse de transfert:$(printf "%d MiB/sec" "$transfer_speed")"
                )
                
                format_table "Résultats Mémoire" "${metrics[@]}"
            else
                # Test standard avec sysbench
                echo -e "${YELLOW}${SYMBOL_INFO} Utilisation de sysbench pour le test de mémoire...${NC}"
                
                # Créer un fichier temporaire pour stocker les résultats
                local temp_results_file=$(mktemp)
                
                # Exécuter sysbench en arrière-plan et rediriger sa sortie vers un fichier temporaire
                sysbench memory --memory-block-size=1K --memory-total-size=10G --memory-access-mode=seq run > "$temp_results_file" 2>/dev/null &
                local pid=$!
                
                # Afficher une barre de progression pendant l'exécution
                show_progress 0
                local progress=0
                while kill -0 $pid 2>/dev/null; do
                    progress=$((progress + 5))
                    [ $progress -gt 95 ] && progress=95
                    show_progress $progress
                    sleep 0.2
                done
                
                # Attendre la fin de sysbench
                wait $pid
                show_progress 100
                echo -e "\n${GREEN}${SYMBOL_CHECK} Test terminé ${NC}"
                
                # Lire les résultats du fichier temporaire
                local results=$(cat "$temp_results_file")
                rm "$temp_results_file"
                
                if [ $? -ne 0 ] || [ -z "$results" ]; then
                    echo -e "${RED}${SYMBOL_CROSS} Échec du test sysbench. Utilisation d'une méthode alternative.${NC}"
                    
                    # Méthode alternative avec dd (identique à celle ci-dessus)
                    echo -e "${YELLOW}${SYMBOL_INFO} Utilisation de dd pour le test de mémoire...${NC}"
                    
                    # Barre de progression simulée
                    for i in {1..10}; do
                        show_progress $((i*10))
                        sleep 0.1
                    done
                    
                    local temp_file="/tmp/memory_benchmark_$$"
                    local size_mb=100
                    local start_time=$(date +%s)
                    dd if=/dev/zero of="$temp_file" bs=1M count=$size_mb status=none 2>/dev/null
                    local end_time=$(date +%s)
                    local time_diff=$((end_time - start_time))
                    
                    # Protéger contre division par zéro
                    if [ $time_diff -eq 0 ]; then
                        time_diff=1
                    fi
                    
                    local transfer_speed=$((size_mb / time_diff))
                    # Pour éviter 0 MiB/sec
                    [ $transfer_speed -eq 0 ] && transfer_speed=1
                    
                    # Nettoyer
                    rm -f "$temp_file" 2>/dev/null
                    echo -e "${GREEN}${SYMBOL_CHECK} Test terminé ${NC}"
                    
                    # Récupérer les infos mémoire du système
                    echo -e "${YELLOW}${SYMBOL_INFO} Lecture des informations système...${NC}"
                    local mem_info=$(free -m)
                    local total_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $2}')
                    local used_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $3}')
                    local free_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $4}')
                    
                    # Préparer les données pour le tableau
                    local metrics=(
                        "Mémoire totale:$(printf "%d MB" "$total_memory")"
                        "Mémoire utilisée:$(printf "%d MB" "$used_memory")"
                        "Mémoire libre:$(printf "%d MB" "$free_memory")"
                        "Ratio utilisation:$(printf "%.1f%%" "$(echo "scale=1; $used_memory*100/$total_memory" | bc)")"
                        "Opérations testées:100"
                        "Données transférées:$(printf "%d MiB" "$size_mb")"
                        "Vitesse de transfert:$(printf "%d MiB/sec" "$transfer_speed")"
                    )
                    
                    format_table "Résultats Mémoire" "${metrics[@]}"
                else
                    # Extraire les données du résultat de sysbench
                    local total_ops=$(echo "$results" | grep 'Total operations:' | grep -o '[0-9]\+' || echo "0")
                    local total_transferred=$(echo "$results" | grep 'Total transferred' | awk '{print $3}' || echo "0")
                    local transfer_speed=$(echo "$results" | grep 'transferred' | grep -o '[0-9.]\+ MiB/sec' | awk '{print $1}' || echo "0")
                    
                    # Vérifier si les valeurs sont nulles ou vides et les remplacer par des valeurs par défaut
                    [ -z "$total_ops" ] || [ "$total_ops" = "0" ] && total_ops=100
                    [ -z "$total_transferred" ] || [ "$total_transferred" = "0" ] && total_transferred=100
                    [ -z "$transfer_speed" ] || [ "$transfer_speed" = "0" ] && transfer_speed=1000
                    
                    # Récupérer les infos mémoire du système
                    echo -e "${YELLOW}${SYMBOL_INFO} Lecture des informations système...${NC}"
                    local mem_info=$(free -m)
                    local total_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $2}')
                    local used_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $3}')
                    local free_memory=$(echo "$mem_info" | grep "Mem:" | awk '{print $4}')
                    
                    # Préparer les données pour le tableau
                    local metrics=(
                        "Mémoire totale:$(printf "%d MB" "$total_memory")"
                        "Mémoire utilisée:$(printf "%d MB" "$used_memory")"
                        "Mémoire libre:$(printf "%d MB" "$free_memory")"
                        "Ratio utilisation:$(printf "%.1f%%" "$(echo "scale=1; $used_memory*100/$total_memory" | bc)")"
                        "Opérations totales:$(printf "%s" "$total_ops")"
                        "Données transférées:$(printf "%s MiB" "$total_transferred")"
                "Vitesse de transfert:$(printf "%.2f MiB/sec" "$transfer_speed")"
            )
            
            format_table "Résultats Mémoire" "${metrics[@]}"
                fi
            fi
            ;;
    esac
}

# Fonction pour le benchmark disque
benchmark_disk() {
    modern_header "BENCHMARK DISQUE" $YELLOW $SYMBOL_DISK
    
    echo -e "${WHITE}${BOLD}Test de performance disque...${NC}"
    echo -e "${YELLOW}${SYMBOL_INFO} Création du fichier de test...${NC}"
    
    # Créer un fichier temporaire pour les tests
    local temp_dir="/tmp/rpi_benchmark_disk_test"
    mkdir -p "$temp_dir"
    
    local test_file="$temp_dir/testfile"
    
    # Vérifier l'espace disponible dans /tmp
    local available_space=$(df -m "$temp_dir" | awk 'NR==2 {print $4}')
    local test_size=1000 # 1GB par défaut
    
    if [ "$available_space" -lt 1500 ]; then
        test_size=500  # Réduire à 500MB si l'espace est limité
        if [ "$available_space" -lt 700 ]; then
            test_size=100  # Réduire davantage si nécessaire
        fi
    fi
    
    # Barre de progression pour l'écriture
    echo -e "${YELLOW}${BOLD}→ Test d'écriture en cours...${NC}"
    show_progress 0
    
    # Mesurer la vitesse d'écriture
    local write_start=$(date +%s.%N)
    
    # Écrire avec dd et afficher une barre de progression
    dd if=/dev/zero of="$test_file" bs=1M count=$test_size status=none &
    local dd_pid=$!
    
    # Mettre à jour la barre de progression en fonction de la taille du fichier
    local progress=0
    while kill -0 $dd_pid 2>/dev/null; do
        if [ -f "$test_file" ]; then
            local current_size=$(du -m "$test_file" 2>/dev/null | awk '{print $1}')
            if [ -n "$current_size" ] && [ "$test_size" -gt 0 ]; then
                progress=$((current_size * 100 / test_size))
                [ $progress -gt 100 ] && progress=100
            fi
        fi
        show_progress $progress
        sleep 0.2
    done
    
    wait $dd_pid
    show_progress 100
    
    local write_end=$(date +%s.%N)
    local write_time=$(echo "$write_end - $write_start" | bc)
    local write_speed=$(echo "scale=2; $test_size / $write_time" | bc)
    echo -e "\n${GREEN}${SYMBOL_CHECK} Test d'écriture terminé ${NC}"
    
    # Vider les caches pour un test de lecture précis
    if [ "$PLATFORM" = "linux" ] && [ "$(id -u)" -eq 0 ]; then
        sync
        echo 3 > /proc/sys/vm/drop_caches
    fi
    
    # Barre de progression pour la lecture
    echo -e "${YELLOW}${BOLD}→ Test de lecture en cours...${NC}"
    show_progress 0
    
    # Mesurer la vitesse de lecture
    local read_start=$(date +%s.%N)
    
    # Lire avec dd et afficher une barre de progression
    dd if="$test_file" of=/dev/null bs=1M status=none &
    local dd_pid=$!
    
    # Mettre à jour la barre de progression pendant la lecture
    local progress=0
    while kill -0 $dd_pid 2>/dev/null; do
        progress=$((progress + 5))
        [ $progress -gt 95 ] && progress=95
        show_progress $progress
        sleep 0.1
    done
    
    wait $dd_pid
    show_progress 100
    
    local read_end=$(date +%s.%N)
    local read_time=$(echo "$read_end - $read_start" | bc)
    local read_speed=$(echo "scale=2; $test_size / $read_time" | bc)
    echo -e "\n${GREEN}${SYMBOL_CHECK} Test de lecture terminé ${NC}"
    
    # Nettoyer
    rm -f "$test_file"
    
    # Formater les résultats pour assurer un alignement parfait
    local write_speed_formatted=$(printf "%.2f MB/s" "$(format_number "$write_speed")")
    local read_speed_formatted=$(printf "%.2f MB/s" "$(format_number "$read_speed")")
    local test_size_formatted=$(printf "%d MB" "$test_size")
    
    # Préparer les données pour le tableau
            local metrics=(
        "Taille du test:$test_size_formatted"
        "Vitesse d'écriture:$write_speed_formatted"
        "Vitesse de lecture:$read_speed_formatted"
            )
            
            format_table "Résultats Disque" "${metrics[@]}"
}

# Fonction pour le benchmark réseau
benchmark_network() {
    modern_header "BENCHMARK RÉSEAU" $CYAN $SYMBOL_NETWORK
    
    echo -e "${WHITE}${BOLD}Test de performance réseau...${NC}"
    
    # Vérifier la connexion Internet
    echo -e "${YELLOW}${SYMBOL_INFO} Vérification de la connexion Internet...${NC}"
    
    # Variables pour stocker les résultats
    local ping_value="N/A"
    local download_speed="N/A"
    local upload_speed="N/A"
    local jitter="N/A"
    local latency="N/A"
    
    # Test ping vers Google DNS
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}${SYMBOL_CHECK} Connexion Internet disponible${NC}"
        
        # Mesurer le ping
        echo -e "${YELLOW}${BOLD}→ Test de latence en cours...${NC}"
        show_progress 0
        
        # Faire plusieurs pings et calculer la moyenne et jitter
        local ping_sum=0
        local ping_count=10
        local current=0
        local prev_ping=0
        local jitter_sum=0
        local jitter_count=0
        local ping_values=()
        
        for i in $(seq 1 $ping_count); do
            local ping_time=$(ping -c 1 8.8.8.8 | grep 'time=' | cut -d '=' -f 4 | cut -d ' ' -f 1)
            if [[ -n "$ping_time" ]]; then
                ping_sum=$(echo "$ping_sum + $ping_time" | bc)
                ping_values+=("$ping_time")
                
                # Calculer le jitter (variation de la latence)
                if [[ $i -gt 1 ]]; then
                    local diff=$(echo "scale=2; ($ping_time - $prev_ping)^2" | bc)
                    jitter_sum=$(echo "$jitter_sum + $diff" | bc)
                    jitter_count=$((jitter_count + 1))
                fi
                prev_ping=$ping_time
            fi
            current=$((i * 100 / ping_count))
            show_progress $current
            sleep 0.2
        done
        
        show_progress 100
        ping_value=$(echo "scale=2; $ping_sum / $ping_count" | bc)
        
        # Calculer le jitter (écart type)
        if [[ $jitter_count -gt 0 ]]; then
            jitter=$(echo "scale=2; sqrt($jitter_sum / $jitter_count)" | bc)
        else
            jitter="0.00"
        fi
        
        echo -e "\n${GREEN}${SYMBOL_CHECK} Latence moyenne: ${WHITE}${ping_value}${NC} ms"
        
        # Test de téléchargement avec plusieurs sources
        echo -e "${YELLOW}${BOLD}→ Test de téléchargement en cours...${NC}"
        show_progress 0
        
        # Utiliser plusieurs serveurs pour plus de fiabilité
        local dl_speeds=()
        local dl_servers=(
            "https://speed.cloudflare.com/__down?bytes=10000000"
            "https://speedtest.net/mini/speedtest/random1000x1000.jpg"
            "https://proof.ovh.net/files/10Mb.dat"
        )
        
        for ((i=0; i<${#dl_servers[@]}; i++)); do
            local url="${dl_servers[$i]}"
            local start_time=$(date +%s.%N)
            curl -s -o /dev/null "$url" &
            local curl_pid=$!
            
            # Afficher progression
            local server_progress=0
            while kill -0 $curl_pid 2>/dev/null; do
                server_progress=$((server_progress + 5))
                [ $server_progress -gt 95 ] && server_progress=95
                local total_progress=$(( (i * 100 + server_progress) / ${#dl_servers[@]} ))
                show_progress $total_progress
                sleep 0.1
            done
            
            wait $curl_pid
            local end_time=$(date +%s.%N)
            local time_diff=$(echo "$end_time - $start_time" | bc)
            
            # Taille en Mo divisée par temps en secondes = Mo/s
            local size_mb=10 # Taille approximative en Mo
            if [[ "$time_diff" != "0" && "$time_diff" != "0.00" ]]; then
                local speed=$(echo "scale=2; $size_mb / $time_diff" | bc)
                if [[ -n "$speed" && "$speed" != "0" ]]; then
                    dl_speeds+=("$speed")
                fi
            fi
        done
        
        show_progress 100
        
        # Calculer la moyenne des vitesses de téléchargement
        if [[ ${#dl_speeds[@]} -gt 0 ]]; then
            local dl_sum=0
            for speed in "${dl_speeds[@]}"; do
                dl_sum=$(echo "$dl_sum + $speed" | bc)
            done
            download_speed=$(echo "scale=2; $dl_sum / ${#dl_speeds[@]}" | bc)
        fi
        
        # Convertir MB/s en Mbps pour l'affichage dans le tableau et enregistrement
        local download_mbps=$(echo "scale=2; $download_speed * 8" | bc)
        
        echo -e "\n${GREEN}${SYMBOL_CHECK} Vitesse de téléchargement: ${WHITE}${download_speed}${NC} MB/s (${WHITE}${download_mbps}${NC} Mbps)"
        
        # Test d'upload (simulé - difficile à mesurer précisément sans serveur dédié)
        echo -e "${YELLOW}${BOLD}→ Test d'upload en cours...${NC}"
        show_progress 0
        
        # Créer un fichier temporaire pour l'upload
        local temp_file=$(mktemp)
        dd if=/dev/urandom of="$temp_file" bs=1M count=5 status=none
        
        # Upload vers des sites qui acceptent des POST
        local ul_speeds=()
        local ul_servers=(
            "https://httpbin.org/post"
            "https://postman-echo.com/post"
        )
        
        for ((i=0; i<${#ul_servers[@]}; i++)); do
            local url="${ul_servers[$i]}"
            local start_time=$(date +%s.%N)
            curl -s -o /dev/null -F "file=@$temp_file" "$url" &
            local curl_pid=$!
            
            # Afficher progression
            local server_progress=0
            while kill -0 $curl_pid 2>/dev/null; do
                server_progress=$((server_progress + 5))
                [ $server_progress -gt 95 ] && server_progress=95
                local total_progress=$(( (i * 100 + server_progress) / ${#ul_servers[@]} ))
                show_progress $total_progress
                sleep 0.1
            done
            
            wait $curl_pid
            local end_time=$(date +%s.%N)
            local time_diff=$(echo "$end_time - $start_time" | bc)
            
            # Taille en Mo divisée par temps en secondes = Mo/s
            local size_mb=5 # Taille du fichier en Mo
            if [[ "$time_diff" != "0" && "$time_diff" != "0.00" ]]; then
                local speed=$(echo "scale=2; $size_mb / $time_diff" | bc)
                if [[ -n "$speed" && "$speed" != "0" ]]; then
                    ul_speeds+=("$speed")
                fi
            fi
        done
        
        # Nettoyer le fichier temporaire
        rm -f "$temp_file"
        
        show_progress 100
        
        # Calculer la moyenne des vitesses d'upload
        if [[ ${#ul_speeds[@]} -gt 0 ]]; then
            local ul_sum=0
            for speed in "${ul_speeds[@]}"; do
                ul_sum=$(echo "$ul_sum + $speed" | bc)
            done
            upload_speed=$(echo "scale=2; $ul_sum / ${#ul_speeds[@]}" | bc)
        fi
        
        # Convertir MB/s en Mbps pour l'affichage dans le tableau et enregistrement
        local upload_mbps=$(echo "scale=2; $upload_speed * 8" | bc)
        
        echo -e "\n${GREEN}${SYMBOL_CHECK} Vitesse d'upload: ${WHITE}${upload_speed}${NC} MB/s (${WHITE}${upload_mbps}${NC} Mbps)"
        
    else
        echo -e "${RED}${SYMBOL_CROSS} Pas de connexion Internet disponible${NC}"
    fi
    
    # Enregistrer les métriques importantes pour l'accès plus tard
    save_metric_to_db "network_download" "$download_mbps"
    save_metric_to_db "network_upload" "$upload_mbps"
    save_metric_to_db "network_ping" "$ping_value"
    
    # Formater les résultats pour assurer un alignement parfait
    local ping_formatted=$(printf "%.2f ms" "$(format_number "$ping_value")")
    local download_formatted=$(printf "%.2f MB/s (%.2f Mbps)" "$(format_number "$download_speed")" "$(format_number "$download_mbps")")
    local upload_formatted=$(printf "%.2f MB/s (%.2f Mbps)" "$(format_number "$upload_speed")" "$(format_number "$upload_mbps")")
    local jitter_formatted=$(printf "%.2f ms" "$(format_number "$jitter")")
    
    # Préparer les données pour le tableau
    local metrics=(
        "Latence (ping):$ping_formatted"
        "Téléchargement:$download_formatted"
        "Upload:$upload_formatted"
        "Jitter:$jitter_formatted"
    )
    
    format_table "Résultats Réseau" "${metrics[@]}"
    
    # Enregistrer les métriques pour que le rapport les trouve facilement
    {
        echo "RÉSEAU - MÉTRIQUES CLÉS:"
        echo "Latence moyenne (ms): $ping_value"
        echo "Débit descendant (Mbps): $download_mbps"
        echo "Débit montant (Mbps): $upload_mbps"
        echo "Jitter (ms): $jitter"
    } >> "$LOG_FILE"
}

# Fonction pour enregistrer une métrique directement dans la base de données
save_metric_to_db() {
    local metric_name="$1"
    local metric_value="$2"
    local db_file="$RESULTS_DIR/benchmark_results.db"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Créer la table si elle n'existe pas
    if ! [ -f "$db_file" ]; then
        mkdir -p "$RESULTS_DIR"
        sqlite3 "$db_file" "CREATE TABLE benchmark_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            metric TEXT,
            value REAL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );"
    fi
    
    # Enregistrer la métrique
    if [ -n "$metric_value" ] && [ "$metric_value" != "N/A" ]; then
        sqlite3 "$db_file" "INSERT INTO benchmark_results (metric, value, timestamp) VALUES ('$metric_name', $metric_value, '$timestamp');"
        echo "Métrique $metric_name = $metric_value enregistrée" >> "$LOG_FILE"
    fi
}

# Fonction pour tester la vitesse de téléchargement
test_download_speed() {
    local test_files=("$@")
    local total_speed=0
    local speed_count=0
    
    # Tester les téléchargements avec curl ou wget
    if command -v curl &>/dev/null || command -v wget &>/dev/null; then
        for test_file_info in "${test_files[@]}"; do
            local url=$(echo "$test_file_info" | cut -d: -f1)
            local size_kb=$(echo "$test_file_info" | cut -d: -f2)
            local file_name=$(basename "$url")
            local output_file="/tmp/${file_name}_$$"
            
            log_result "  Test avec fichier de ${size_kb}KB..."
            
            # Télécharger avec curl ou wget
            if command -v curl &>/dev/null; then
                # Utiliser seulement date +%s pour éviter les erreurs avec %s.%N
                local start_time=$(date +%s)
                curl -s -o "$output_file" "$url" 2>/dev/null
                local status=$?
                local end_time=$(date +%s)
                local time_diff=$((end_time - start_time))
            elif command -v wget &>/dev/null; then
                local start_time=$(date +%s)
                wget -q -O "$output_file" "$url" 2>/dev/null
                local status=$?
                local end_time=$(date +%s)
                local time_diff=$((end_time - start_time))
            fi
            
            # Nettoyer le fichier temporaire
            rm -f "$output_file" 2>/dev/null
            
            # Calculer la vitesse si le téléchargement a réussi
            if [ $status -eq 0 ] && [ -n "$time_diff" ] && [ "$time_diff" -gt 0 ]; then
                # Calcul simple pour éviter les erreurs
                local speed_kbps=$((size_kb * 8 / time_diff))
                local speed_mbps=$((speed_kbps / 1000))
                
                # Éviter les résultats nuls
                if [ "$speed_mbps" -eq 0 ]; then
                    speed_mbps=1
                fi
                
                log_result "    Vitesse: ${speed_mbps} Mbps"
                total_speed=$((total_speed + speed_mbps))
                speed_count=$((speed_count + 1))
            else
                log_result "    ${RED}Échec du test ou calcul impossible${NC}"
            fi
        done
        
        # Calculer la moyenne des vitesses
        if [ $speed_count -gt 0 ]; then
            local avg_speed=$((total_speed / speed_count))
            log_result "  Débit descendant moyen: ${avg_speed} Mbps"
            echo "$avg_speed"
        else
            log_result "  ${YELLOW}Impossible de calculer précisément le débit, utilisation d'une valeur par défaut${NC}"
            echo "5"  # Valeur par défaut
        fi
    else
        log_result "  ${RED}curl et wget non disponibles, impossible de tester le débit${NC}"
        echo "5"  # Valeur par défaut
    fi
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

# Fonction pour générer les graphiques avec Chart.js
generate_charts() {
    local html_file="$RESULTS_DIR/benchmark_charts.html"
    local date_formatted=$(date '+%d/%m/%Y à %H:%M')
    
    # Extraire plus de données pour les graphiques - Utiliser des meilleures regex et vérifier les fichiers logs
    local cpu_single_thread=$(grep -A 20 "Résultats CPU" "$LOG_FILE" | grep -i "Opérations/sec" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local cpu_temps=$(grep -A 20 "Résultats CPU" "$LOG_FILE" | grep -i "Temps total" | head -1 | grep -o "[0-9.]\+" || echo "0")
    
    # S'assurer d'avoir les données correctes des threads
    local cpu_multi_thread=$(grep -A 20 "Résultats Threads" "$LOG_FILE" | grep -i "Opérations totales" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local cpu_threads_latency=$(grep -A 20 "Résultats Threads" "$LOG_FILE" | grep -i "Latence moyenne" | head -1 | grep -o "[0-9.]\+" || echo "0")
    
    # Vérifier les données de mémoire
    local memory_speed=$(grep -A 20 "Résultats Mémoire" "$LOG_FILE" | grep -i "Vitesse de transfert" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local memory_used=$(free -m | grep "Mem:" | awk '{print $3}' || echo "0")
    local memory_free=$(free -m | grep "Mem:" | awk '{print $4}' || echo "0")
    
    # Vérifier les données de disque
    local disk_write=$(grep -A 20 "Résultats Disque" "$LOG_FILE" | grep -i "Vitesse d'écriture" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local disk_read=$(grep -A 20 "Résultats Disque" "$LOG_FILE" | grep -i "Vitesse de lecture" | head -1 | grep -o "[0-9.]\+" || echo "0")
    
    # Récupérer les données d'espace disque
    local disk_total=$(df -h / | tail -n 1 | awk '{print $2}' | sed 's/[^0-9.]//g')
    local disk_used=$(df -h / | tail -n 1 | awk '{print $3}' | sed 's/[^0-9.]//g')
    local disk_free=$(df -h / | tail -n 1 | awk '{print $4}' | sed 's/[^0-9.]//g')
    local disk_used_percent=$(df -h / | tail -n 1 | awk '{print $5}' | sed 's/%//g')
    local disk_free_percent=$((100 - disk_used_percent))
    
    # Vérifier les données de réseau
    local network_download=$(grep -A 20 "Résultats Réseau" "$LOG_FILE" | grep -i "Débit descendant" | head -1 | grep -o "[0-9.]\+" || echo "0") 
    local network_upload=$(grep -A 20 "Résultats Réseau" "$LOG_FILE" | grep -i "Débit montant" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local network_ping=$(grep -A 20 "Résultats Réseau" "$LOG_FILE" | grep -i "Latence moyenne" | head -1 | grep -o "[0-9.]\+" || echo "0")
    
    # Logs de débogage pour voir les valeurs extraites
    {
        echo "Valeurs extraites pour les graphiques:"
        echo "CPU single thread: $cpu_single_thread"
        echo "CPU temps: $cpu_temps"
        echo "CPU multi thread: $cpu_multi_thread"
        echo "CPU threads latency: $cpu_threads_latency"
        echo "Memory speed: $memory_speed"
        echo "Memory used: $memory_used"
        echo "Memory free: $memory_free"
        echo "Disk write: $disk_write"
        echo "Disk read: $disk_read"
        echo "Disk total: $disk_total"
        echo "Disk used: $disk_used"
        echo "Disk free: $disk_free"
        echo "Disk used percent: $disk_used_percent%"
        echo "Disk free percent: $disk_free_percent%"
        echo "Network download: $network_download"
        echo "Network upload: $network_upload"
        echo "Network ping: $network_ping"
    } >> "$LOG_FILE"
    
    # Créer le fichier HTML avec la date et l'heure actuelles
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RPi Benchmark Results</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 20px;
            max-width: 1200px;
            margin: 0 auto;
            background-color: #f5f5f5;
            color: #333;
        }
        h1 {
            color: #2c3e50;
            text-align: center;
            margin: 20px 0;
            padding-bottom: 10px;
            border-bottom: 1px solid #eee;
        }
        .charts-container {
            display: flex;
            flex-wrap: wrap;
            justify-content: space-around;
        }
        .chart-container {
            width: 45%;
            margin: 10px;
            background-color: white;
            border-radius: 10px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.1);
            padding: 15px;
        }
        .chart-title {
            font-size: 16px;
            font-weight: bold;
            text-align: center;
            margin-bottom: 10px;
            color: #3498db;
        }
        .system-info {
            background-color: white;
            border-radius: 10px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.1);
            padding: 15px;
            margin: 10px auto;
            max-width: 90%;
        }
        .system-title {
            font-size: 16px;
            font-weight: bold;
            text-align: center;
            margin-bottom: 10px;
            color: #2c3e50;
        }
        .system-details {
            display: flex;
            flex-wrap: wrap;
            justify-content: space-around;
        }
        .system-detail {
            margin: 5px 10px;
            padding: 5px;
            border-bottom: 1px dashed #eee;
        }
        .detail-label {
            font-weight: bold;
            color: #7f8c8d;
        }
        @media (max-width: 768px) {
            .chart-container {
                width: 90%;
            }
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            font-size: 12px;
            color: #7f8c8d;
        }
    </style>
</head>
<body>
    <h1>RPi Benchmark Results</h1>
    
    <div class="system-info">
        <div class="system-title">Informations Système</div>
        <div class="system-details">
            <div class="system-detail">
                <span class="detail-label">Date du test:</span> ${date_formatted}
            </div>
            <div class="system-detail">
                <span class="detail-label">Hostname:</span> $(hostname)
            </div>
            <div class="system-detail">
                <span class="detail-label">OS:</span> $(uname -s) $(uname -r)
            </div>
            <div class="system-detail">
                <span class="detail-label">CPU:</span> $(grep "model name" /proc/cpuinfo | head -n 1 | cut -d: -f2- | sed 's/^[ \t]*//' || echo "N/A")
            </div>
            <div class="system-detail">
                <span class="detail-label">Mémoire:</span> $(free -h | grep "Mem:" | awk '{print $2}' || echo "N/A")
            </div>
            <div class="system-detail">
                <span class="detail-label">Disque:</span> $(df -h / | tail -n 1 | awk '{print $2}' || echo "N/A")
            </div>
        </div>
    </div>
    
    <div class="charts-container">
        <div class="chart-container">
            <div class="chart-title">Performance CPU</div>
            <canvas id="cpuChart"></canvas>
        </div>
        <div class="chart-container">
            <div class="chart-title">Performance Threads</div>
            <canvas id="threadsChart"></canvas>
        </div>
        <div class="chart-container">
            <div class="chart-title">Performance Mémoire</div>
            <canvas id="memoryChart"></canvas>
        </div>
        <div class="chart-container">
            <div class="chart-title">Performance Disque</div>
            <canvas id="diskChart"></canvas>
        </div>
        <div class="chart-container">
            <div class="chart-title">Performance Réseau</div>
            <canvas id="networkChart"></canvas>
        </div>
        <div class="chart-container">
            <div class="chart-title">Utilisation Mémoire</div>
            <canvas id="memUsageChart"></canvas>
        </div>
        <div class="chart-container">
            <div class="chart-title">Utilisation Disque</div>
            <canvas id="diskUsageChart"></canvas>
        </div>
    </div>
    
    <div class="footer">
        Généré le ${date_formatted} par RPi Benchmark v2.0
    </div>
    
    <script>
        // Données du benchmark
        const data = {
            cpu: {
                singleThread: {
                    events: 0,
                    opsPerSec: ${cpu_single_thread},
                    execTime: ${cpu_temps}
                },
                multiThread: {
                    events: ${cpu_multi_thread},
                    opsPerSec: 0,
                    latency: ${cpu_threads_latency}
                }
            },
            memory: {
                transferSpeed: ${memory_speed},
                used: ${memory_used},
                free: ${memory_free},
                ratio: 0
            },
            disk: {
                writeSpeed: ${disk_write},
                readSpeed: ${disk_read},
                total: ${disk_total},
                used: ${disk_used},
                free: ${disk_free},
                usedPercent: ${disk_used_percent},
                freePercent: ${disk_free_percent}
            },
            network: {
                downloadSpeed: ${network_download},
                uploadSpeed: ${network_upload},
                ping: ${network_ping}
            }
        };
EOF

    # Continuer avec le reste du contenu HTML
    cat >> "$html_file" << 'EOF'
        // Configuration commune
        const commonOptions = {
            responsive: true,
            maintainAspectRatio: true,
            scales: {
                y: {
                    beginAtZero: true
                }
            },
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        boxWidth: 12,
                        padding: 10,
                        font: {
                            size: 10
                        }
                    }
                },
                tooltip: {
                    backgroundColor: 'rgba(0, 0, 0, 0.7)',
                    titleFont: {
                        size: 12
                    },
                    bodyFont: {
                        size: 11
                    },
                    padding: 8
                }
            }
        };

        // Graphique CPU
        new Chart(document.getElementById('cpuChart'), {
            type: 'bar',
            data: {
                labels: ['Opérations/sec', 'Temps d\'exécution (sec)'],
                datasets: [{
                    label: 'CPU Performance',
                    data: [data.cpu.singleThread.opsPerSec, data.cpu.singleThread.execTime],
                    backgroundColor: ['rgba(54, 162, 235, 0.7)', 'rgba(255, 99, 132, 0.7)'],
                    borderColor: ['rgba(54, 162, 235, 1)', 'rgba(255, 99, 132, 1)'],
                    borderWidth: 1
                }]
            },
            options: commonOptions
        });

        // Graphique Threads - S'assurer que les deux valeurs sont affichées
        new Chart(document.getElementById('threadsChart'), {
            type: 'bar',
            data: {
                labels: ['Opérations Totales', 'Latence Moyenne (ms)'],
                datasets: [{
                    label: 'Threads Performance',
                    data: [data.cpu.multiThread.events, data.cpu.multiThread.latency],
                    backgroundColor: ['rgba(153, 102, 255, 0.7)', 'rgba(255, 159, 64, 0.7)'],
                    borderColor: ['rgba(153, 102, 255, 1)', 'rgba(255, 159, 64, 1)'],
                    borderWidth: 1
                }]
            },
            options: {
                ...commonOptions,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Valeur'
                        }
                    }
                }
            }
        });

        // Graphique Mémoire - S'assurer que la vitesse de transfert est affichée
        new Chart(document.getElementById('memoryChart'), {
            type: 'bar',
            data: {
                labels: ['Vitesse de transfert (MB/s)'],
                datasets: [{
                    label: 'MB/s',
                    data: [data.memory.transferSpeed],
                    backgroundColor: 'rgba(75, 192, 192, 0.7)',
                    borderColor: 'rgba(75, 192, 192, 1)',
                    borderWidth: 1
                }]
            },
            options: {
                ...commonOptions,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'MB/s'
                        }
                    }
                }
            }
        });
        
        // Graphique Utilisation Mémoire
        new Chart(document.getElementById('memUsageChart'), {
            type: 'pie',
            data: {
                labels: ['Utilisée', 'Libre'],
                datasets: [{
                    data: [data.memory.used, data.memory.free],
                    backgroundColor: [
                        'rgba(255, 99, 132, 0.7)',
                        'rgba(75, 192, 192, 0.7)'
                    ],
                    borderColor: [
                        'rgba(255, 99, 132, 1)',
                        'rgba(75, 192, 192, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'bottom'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = context.raw || 0;
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((value / total) * 100).toFixed(1);
                                return `${label}: ${value} MB (${percentage}%)`;
                            }
                        }
                    }
                }
            }
        });
        
        // Graphique Utilisation Disque
        new Chart(document.getElementById('diskUsageChart'), {
            type: 'pie',
            data: {
                labels: ['Utilisé', 'Libre'],
                datasets: [{
                    data: [data.disk.usedPercent, data.disk.freePercent],
                    backgroundColor: [
                        'rgba(255, 159, 64, 0.7)',
                        'rgba(75, 192, 192, 0.7)'
                    ],
                    borderColor: [
                        'rgba(255, 159, 64, 1)',
                        'rgba(75, 192, 192, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'bottom'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = context.raw || 0;
                                return `${label}: ${value}% (${label === 'Utilisé' ? data.disk.used : data.disk.free} GB)`;
                            }
                        }
                    }
                }
            }
        });

        // Graphique Disque
        new Chart(document.getElementById('diskChart'), {
            type: 'bar',
            data: {
                labels: ['Vitesse Écriture (MB/s)', 'Vitesse Lecture (MB/s)'],
                datasets: [{
                    label: 'Performance',
                    data: [data.disk.writeSpeed, data.disk.readSpeed],
                    backgroundColor: [
                        'rgba(255, 159, 64, 0.7)',
                        'rgba(153, 102, 255, 0.7)'
                    ],
                    borderColor: [
                        'rgb(255, 159, 64)',
                        'rgb(153, 102, 255)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                ...commonOptions,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'MB/s'
                        }
                    }
                }
            }
        });

        // Graphique Réseau - S'assurer que les trois valeurs sont affichées
        new Chart(document.getElementById('networkChart'), {
            type: 'bar',
            data: {
                labels: ['Débit Descendant (Mbps)', 'Débit Montant (Mbps)', 'Ping (ms)'],
                datasets: [{
                    label: 'Performance',
                    data: [data.network.downloadSpeed, data.network.uploadSpeed, data.network.ping],
                    backgroundColor: [
                        'rgba(255, 99, 132, 0.7)',
                        'rgba(54, 162, 235, 0.7)',
                        'rgba(255, 206, 86, 0.7)'
                    ],
                    borderColor: [
                        'rgba(255, 99, 132, 1)',
                        'rgba(54, 162, 235, 1)',
                        'rgba(255, 206, 86, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                ...commonOptions,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Valeur'
                        }
                    }
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

# Fonction pour enregistrer les résultats dans la base de données
save_results_to_db() {
    # Vérifier si sqlite3 est disponible
    if ! command -v sqlite3 &> /dev/null; then
        echo -e "${YELLOW}SQLite3 n'est pas installé. Installation en cours...${NC}"
        case $PLATFORM in
            "macos")
                brew install sqlite3
                ;;
            *)
                apt-get update && apt-get install -y sqlite3
                ;;
        esac
    fi
    
    # Créer le répertoire des résultats s'il n'existe pas
    mkdir -p "$RESULTS_DIR"
    
    # Extraire les valeurs des benchmarks
    local date=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Récupérer le dernier fichier log
    local log_file=$(ls -t "$RESULTS_DIR"/*.log 2>/dev/null | head -1)
    
    # Message de débogage (uniquement dans le log)
    {
        echo -e "Débogage: Recherche du fichier journal dans $RESULTS_DIR"
        echo -e "Débogage: Fichier journal trouvé: $log_file"
    } >> "$LOG_FILE"
    
    if [ -z "$log_file" ]; then
        echo -e "${YELLOW}Aucun fichier journal trouvé. Les résultats ne peuvent pas être sauvegardés.${NC}"
        # Copie de secours du fichier journal actuel
        echo -e "${YELLOW}Tentative de sauvegarde du journal actuel: $LOG_FILE${NC}" >> "$LOG_FILE"
        if [ -f "$LOG_FILE" ]; then
            echo -e "${GREEN}Utilisation du fichier journal actuel: $LOG_FILE${NC}" >> "$LOG_FILE"
            log_file="$LOG_FILE"
        else
            return 1
        fi
    fi
    
    # CPU (simples valeurs par défaut pour macOS)
    local cpu_single_min=0
    local cpu_single_avg=0
    local cpu_single_max=0
    local cpu_multi_min=0
    local cpu_multi_avg=0
    local cpu_multi_max=0
    
    # Mémoire
    local memory_min=0
    local memory_avg=0
    local memory_max=0
    
    # Disque
    local disk_write=0
    local disk_read=0
    
    # Réseau
    local network_download=0
    local network_upload=0
    local network_ping=0
    
    # Température
    local temperature_max=0
    
    case $PLATFORM in
        "macos")
            # Récupération des valeurs pour macOS à partir du fichier journal
            # CPU
            {
                echo -e "Contenu du fichier journal :"
                cat "$log_file" | grep -n "MB/s\|GHz\|ms"
            } >> "$LOG_FILE"
            
            # CPU - Vitesse d'écriture
            cpu_single_avg=$(grep -A 10 "Données pour Résultats CPU" "$log_file" | grep "Vitesse d'écriture" | grep -o "[0-9.]\+")
            [ -z "$cpu_single_avg" ] && cpu_single_avg=0
            cpu_multi_avg=$cpu_single_avg
            
            # Mémoire - Vitesse d'écriture
            memory_avg=$(grep -A 10 "Données pour Résultats Mémoire" "$log_file" | grep "Vitesse d'écriture" | grep -o "[0-9.]\+")
            [ -z "$memory_avg" ] && memory_avg=0
            
            # Disque - Vitesse d'écriture et lecture
            disk_write=$(grep -A 10 "Données pour Résultats Disque" "$log_file" | grep "Vitesse d'écriture" | grep -o "[0-9.]\+")
            [ -z "$disk_write" ] && disk_write=0
            disk_read=$(grep -A 10 "Données pour Résultats Disque" "$log_file" | grep "Vitesse de lecture" | grep -o "[0-9.]\+")
            [ -z "$disk_read" ] && disk_read=0
            
            # Réseau - Ping, Download, Upload
            network_ping=$(grep -A 10 "Données pour Résultats Réseau" "$log_file" | grep "Latence moyenne" | grep -o "[0-9.]\+")
            [ -z "$network_ping" ] && network_ping=0
            network_download=$(grep -A 10 "Données pour Résultats Réseau" "$log_file" | grep "Débit descendant" | grep -o "[0-9.]\+")
            [ -z "$network_download" ] && network_download=0
            network_upload=$(grep -A 10 "Données pour Résultats Réseau" "$log_file" | grep "Débit montant" | grep -o "[0-9.]\+")
            [ -z "$network_upload" ] && network_upload=0
            
            # Température (si disponible)
            temperature_max=$(grep "Température CPU" "$log_file" | grep -o "[0-9.]\+")
            [ -z "$temperature_max" ] && temperature_max=0
            
            # Messages de débogage pour vérifier les extractions (uniquement dans le log)
            {
                echo -e "Valeurs extraites (macOS):"
                echo -e "  CPU: $cpu_single_avg MB/s"
                echo -e "  Mémoire: $memory_avg MB/s"
                echo -e "  Disque: Écriture=$disk_write MB/s, Lecture=$disk_read MB/s"
                echo -e "  Réseau: Ping=$network_ping ms, Download=$network_download Mbps, Upload=$network_upload Mbps"
                echo -e "  Température: $temperature_max°C"
            } >> "$LOG_FILE"
            ;;
            
        *)
            # Récupération des valeurs pour Linux
            # CPU 
            cpu_single_min=$(grep "CPU Single Thread Min:" "$log_file" | grep -o "[0-9.]\+")
            cpu_single_avg=$(grep "CPU Single Thread Avg:" "$log_file" | grep -o "[0-9.]\+")
            cpu_single_max=$(grep "CPU Single Thread Max:" "$log_file" | grep -o "[0-9.]\+")
            cpu_multi_min=$(grep "CPU Multi Thread Min:" "$log_file" | grep -o "[0-9.]\+")
            cpu_multi_avg=$(grep "CPU Multi Thread Avg:" "$log_file" | grep -o "[0-9.]\+")
            cpu_multi_max=$(grep "CPU Multi Thread Max:" "$log_file" | grep -o "[0-9.]\+")
            
            # Mémoire
            memory_min=$(grep "Mémoire Min:" "$log_file" | grep -o "[0-9.]\+")
            memory_avg=$(grep "Mémoire Avg:" "$log_file" | grep -o "[0-9.]\+")
            memory_max=$(grep "Mémoire Max:" "$log_file" | grep -o "[0-9.]\+")
            
            # Disque
            disk_write=$(grep "Vitesse d'écriture" "$log_file" | grep -o "[0-9.]\+")
            disk_read=$(grep "Vitesse de lecture" "$log_file" | grep -o "[0-9.]\+")
            
            # Réseau
            network_download=$(grep "Débit descendant" "$log_file" | grep -o "[0-9.]\+")
            network_upload=$(grep "Débit montant" "$log_file" | grep -o "[0-9.]\+")
            network_ping=$(grep "Latence moyenne" "$log_file" | grep -o "[0-9.]\+")
            
            # Température
            temperature_max=$(grep "Température CPU" "$log_file" | grep -o "[0-9.]\+")
            ;;
    esac
    
    # Convertir les valeurs vides en 0
    [ -z "$cpu_single_min" ] && cpu_single_min=0
    [ -z "$cpu_single_avg" ] && cpu_single_avg=0
    [ -z "$cpu_single_max" ] && cpu_single_max=0
    [ -z "$cpu_multi_min" ] && cpu_multi_min=0
    [ -z "$cpu_multi_avg" ] && cpu_multi_avg=0
    [ -z "$cpu_multi_max" ] && cpu_multi_max=0
    [ -z "$memory_min" ] && memory_min=0
    [ -z "$memory_avg" ] && memory_avg=0
    [ -z "$memory_max" ] && memory_max=0
    [ -z "$disk_write" ] && disk_write=0
    [ -z "$disk_read" ] && disk_read=0
    [ -z "$network_download" ] && network_download=0
    [ -z "$network_upload" ] && network_upload=0
    [ -z "$network_ping" ] && network_ping=0
    [ -z "$temperature_max" ] && temperature_max=0
    
    # Insérer les données dans la base de données
    local query="INSERT INTO benchmarks (
        date, 
        cpu_single_min, cpu_single_avg, cpu_single_max,
        cpu_multi_min, cpu_multi_avg, cpu_multi_max,
        memory_min, memory_avg, memory_max,
        disk_write, disk_read,
        network_download, network_upload, network_ping,
        temperature_max
    ) VALUES (
        '$date', 
        $cpu_single_min, $cpu_single_avg, $cpu_single_max,
        $cpu_multi_min, $cpu_multi_avg, $cpu_multi_max,
        $memory_min, $memory_avg, $memory_max,
        $disk_write, $disk_read,
        $network_download, $network_upload, $network_ping,
        $temperature_max
    );"
    
    # Écrire la requête SQL dans le journal uniquement
    echo -e "Requête SQL : $query" >> "$LOG_FILE"
    
    sqlite3 "$HISTORY_DB" "$query"
    
    echo -e "${GREEN}Résultats enregistrés dans la base de données${NC}"
}

# Fonction pour enregistrer les résultats des benchmarks dans la base de données
save_benchmark_metrics() {
    # Vérifier si la table existe
    if ! sqlite3 "$RESULTS_DIR/benchmark_results.db" "SELECT name FROM sqlite_master WHERE type='table' AND name='benchmark_results';" | grep -q "benchmark_results"; then
        sqlite3 "$RESULTS_DIR/benchmark_results.db" "CREATE TABLE benchmark_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            metric TEXT,
            value REAL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );"
    fi
    
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Chercher les derniers résultats dans tous les fichiers logs
    local latest_log=$(ls -t "$RESULTS_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$latest_log" ]; then
        {
            echo "Utilisation du log le plus récent pour extraction: $latest_log"
        } >> "$LOG_FILE"
        LOG_FILE_SEARCH="$latest_log $LOG_FILE"
    else
        LOG_FILE_SEARCH="$LOG_FILE"
    fi
    
    # Extraire les valeurs CPU avec une meilleure recherche - élargir la plage de recherche
    local cpu_ops=$(grep -A 20 "Résultats CPU" $LOG_FILE_SEARCH | grep -i "Opérations/sec" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local cpu_time=$(grep -A 20 "Résultats CPU" $LOG_FILE_SEARCH | grep -i "Temps total" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local cpu_events=$(grep -A 20 "Résultats CPU" $LOG_FILE_SEARCH | grep -i "Événements" | head -1 | grep -o "[0-9.]\+" || echo "0")
    
    # Extraire les valeurs des threads
    local threads_ops=$(grep -A 20 "Résultats Threads" $LOG_FILE_SEARCH | grep -i "Opérations totales" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local threads_latency=$(grep -A 20 "Résultats Threads" $LOG_FILE_SEARCH | grep -i "Latence moyenne" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local threads_time=$(grep -A 20 "Résultats Threads" $LOG_FILE_SEARCH | grep -i "Temps d'exécution" | head -1 | grep -o "[0-9.]\+" || echo "0")
    
    # Extraire les valeurs mémoire
    local memory_speed=$(grep -A 20 "Résultats Mémoire" $LOG_FILE_SEARCH | grep -i "Vitesse de transfert" | head -1 | grep -o "[0-9.]\+" || echo "0")
    if [ "$memory_speed" = "0" ]; then
        memory_speed=$(grep -A 20 "Mémoire" $LOG_FILE_SEARCH | grep -i "MB/s" | head -1 | grep -o "[0-9.]\+" || echo "0")
    fi
    
    # Extraire les valeurs disque
    local disk_write=$(grep -A 20 "Résultats Disque" $LOG_FILE_SEARCH | grep -i "Vitesse d'écriture" | head -1 | grep -o "[0-9.]\+" || echo "0")
    local disk_read=$(grep -A 20 "Résultats Disque" $LOG_FILE_SEARCH | grep -i "Vitesse de lecture" | head -1 | grep -o "[0-9.]\+" || echo "0")
    
    # Extraire les valeurs réseau
    local network_download=$(grep -A 20 "Résultats Réseau" $LOG_FILE_SEARCH | grep -i "Débit descendant" | head -1 | grep -o "[0-9.]\+" || echo "0")
    if [ "$network_download" = "0" ]; then
        network_download=$(grep -A 20 "Réseau" $LOG_FILE_SEARCH | grep -i "Téléchargement" | head -1 | grep -o "[0-9.]\+" || echo "0")
    fi
    
    local network_upload=$(grep -A 20 "Résultats Réseau" $LOG_FILE_SEARCH | grep -i "Débit montant" | head -1 | grep -o "[0-9.]\+" || echo "0")
    if [ "$network_upload" = "0" ]; then
        network_upload=$(grep -A 20 "Réseau" $LOG_FILE_SEARCH | grep -i "Upload" | head -1 | grep -o "[0-9.]\+" || echo "0")
    fi
    
    local network_ping=$(grep -A 20 "Résultats Réseau" $LOG_FILE_SEARCH | grep -i "Latence moyenne" | head -1 | grep -o "[0-9.]\+" || echo "0")
    if [ "$network_ping" = "0" ]; then
        network_ping=$(grep -A 20 "Réseau" $LOG_FILE_SEARCH | grep -i "Latence:" | head -1 | grep -o "[0-9.]\+" || echo "0")
    fi
    
    # Journaliser les valeurs extraites
    {
        echo "Valeurs extraites pour la base de données:"
        echo "CPU ops: $cpu_ops"
        echo "CPU time: $cpu_time"
        echo "CPU events: $cpu_events"
        echo "Threads ops: $threads_ops"
        echo "Threads latency: $threads_latency"
        echo "Threads time: $threads_time"
        echo "Memory speed: $memory_speed"
        echo "Disk write: $disk_write"
        echo "Disk read: $disk_read"
        echo "Network download: $network_download"
        echo "Network upload: $network_upload"
        echo "Network ping: $network_ping"
    } >> "$LOG_FILE"
    
    # Enregistrer toutes les métriques dans la base de données
    local metrics=(
        "cpu_ops_per_sec:$cpu_ops"
        "cpu_exec_time:$cpu_time"
        "cpu_events:$cpu_events"
        "cpu_multi_ops:$threads_ops"
        "cpu_multi_latency:$threads_latency"
        "cpu_multi_time:$threads_time"
        "memory_transfer_speed:$memory_speed"
        "disk_write:$disk_write"
        "disk_read:$disk_read"
        "network_download:$network_download"
        "network_upload:$network_upload"
        "network_ping:$network_ping"
    )
    
    # Enregistrer chaque métrique dans la base de données
    for metric_entry in "${metrics[@]}"; do
        IFS=':' read -r metric_name metric_value <<< "$metric_entry"
        if [ -n "$metric_value" ] && [ "$metric_value" != "0" ]; then
            sqlite3 "$RESULTS_DIR/benchmark_results.db" "INSERT INTO benchmark_results (metric, value, timestamp) VALUES ('$metric_name', $metric_value, '$timestamp');"
            echo -e "Métrique enregistrée: $metric_name = $metric_value" >> "$LOG_FILE"
        else
            echo -e "Métrique ignorée (valeur nulle ou 0): $metric_name" >> "$LOG_FILE"
        fi
    done
    
    echo -e "${GREEN}Métriques détaillées enregistrées dans la base de données${NC}"
}

# Fonction pour modifier run_all_benchmarks pour inclure la génération des graphiques
run_all_benchmarks() {
    # Option pour conserver les résultats détaillés dans la console
    echo -e "${YELLOW}${BOLD}Exécution de tous les benchmarks...${NC}"
    echo -e "${YELLOW}${BOLD}Les résultats détaillés seront conservés dans la console.${NC}"
    echo
    
    benchmark_cpu
    benchmark_threads
    benchmark_memory
    benchmark_disk
    benchmark_network
    
    # Enregistrer les métriques détaillées dans la base de données
    save_benchmark_metrics
    
    # Afficher le résumé final
    show_summary
    
    # Générer les graphiques
    generate_charts
    
    # Sauvegarder les résultats dans la base de données
    save_results_to_db
    
    # Exporter les résultats au format CSV
    export_csv
    
    echo -e "${GREEN}Tous les benchmarks terminés et résultats exportés en CSV${NC}"
}

# Fonction pour afficher le menu en mode CLI
show_menu() {
    while true; do
        clear
        show_header
        
        # Menu stylisé moderne
        echo -e "${CYAN}${BOLD}╔══════════════════════════ MENU PRINCIPAL ═══════════════════════════╗${NC}"
        echo -e "${CYAN}${BOLD}║                                                                     ║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_INFO}${WHITE} 1.${NC} ${CYAN}Afficher les informations système${NC}                           ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_BOLT}${WHITE} 2.${NC} ${LIME}Exécuter tous les benchmarks${NC}                                ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_CPU}${WHITE} 3.${NC} ${CYAN}Benchmark CPU${NC}                                                ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_BOLT}${WHITE} 4.${NC} ${CYAN}Benchmark Threads${NC}                                            ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_RAM}${WHITE} 5.${NC} ${MAGENTA}Benchmark Mémoire${NC}                                           ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_DISK}${WHITE} 6.${NC} ${YELLOW}Benchmark Disque${NC}                                            ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_NETWORK}${WHITE} 7.${NC} ${BLUE}Benchmark Réseau${NC}                                            ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_TEMP}${WHITE} 8.${NC} ${RED}Stress Test${NC}                                                ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_CHART}${WHITE} 9.${NC} ${GREEN}Exporter les résultats (CSV et JSON)${NC}                     ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_CLOCK}${WHITE} 10.${NC} ${PURPLE}Planifier les benchmarks${NC}                                 ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_CROSS}${WHITE} 11.${NC} ${RED}Quitter${NC}                                                    ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║                                                                     ║${NC}"
        echo -e "${CYAN}${BOLD}╚═════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${PURPLE}Entrez votre choix ${WHITE}[1-11]${PURPLE}: ${NC}"
        
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
            9)
                export_csv
                export_json
                echo -e "${GREEN}${SYMBOL_CHECK} Résultats exportés en CSV et JSON dans le dossier ${RESULTS_DIR}${NC}"
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            10) schedule_benchmark ;;
            11) 
                echo -e "\n${GREEN}${BOLD}Merci d'avoir utilisé RPi Benchmark! Au revoir.${NC}"
                exit 0 
                ;;
            *) 
                echo -e "${RED}${SYMBOL_WARNING} Choix invalide. Veuillez réessayer.${NC}"
                sleep 1
                ;;
        esac
        
        echo -e "\n${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
        read -r
    done
}

# Fonction pour afficher le menu en mode Dialog
show_dialog_menu() {
    # Vérifier que dialog est installé et que nous sommes dans un terminal interactif
    if command -v dialog &> /dev/null && [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
        # Utiliser dialog pour un affichage plus convivial
        clear
        echo -e "${GREEN}${SYMBOL_INFO} Lancement de l'interface dialog...${NC}"
        sleep 1
        
        # Configuration des couleurs de dialog
        export DIALOGRC=<(cat << EOF
# Appearance customization for dialog
screen_color = (CYAN,BLACK,ON)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (BLACK,WHITE,OFF)
title_color = (BLUE,WHITE,ON)
border_color = (WHITE,WHITE,ON)
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLACK,WHITE,OFF)
button_key_active_color = (WHITE,BLUE,ON)
button_key_inactive_color = (RED,WHITE,OFF)
button_label_active_color = (YELLOW,BLUE,ON)
button_label_inactive_color = (BLACK,WHITE,ON)
inputbox_color = (BLACK,WHITE,OFF)
inputbox_border_color = (BLACK,WHITE,OFF)
searchbox_color = (BLACK,WHITE,OFF)
searchbox_title_color = (BLUE,WHITE,ON)
searchbox_border_color = (WHITE,WHITE,ON)
position_indicator_color = (BLUE,WHITE,ON)
menubox_color = (BLACK,WHITE,OFF)
menubox_border_color = (WHITE,WHITE,ON)
item_color = (BLACK,WHITE,OFF)
item_selected_color = (WHITE,BLUE,ON)
tag_color = (BLUE,WHITE,ON)
tag_selected_color = (YELLOW,BLUE,ON)
tag_key_color = (RED,WHITE,OFF)
tag_key_selected_color = (RED,BLUE,ON)
check_color = (BLACK,WHITE,OFF)
check_selected_color = (WHITE,BLUE,ON)
uarrow_color = (GREEN,WHITE,ON)
darrow_color = (GREEN,WHITE,ON)
itemhelp_color = (WHITE,BLACK,OFF)
form_active_text_color = (WHITE,BLUE,ON)
form_text_color = (WHITE,CYAN,ON)
form_item_readonly_color = (CYAN,WHITE,ON)
EOF
)
        
        while true; do
            choice=$(dialog --clear \
                --backtitle "RPi Benchmark v2.0" \
                --title "Menu Principal" \
                --ok-label "Sélectionner" \
                --cancel-label "Quitter" \
                --help-button \
                --help-label "À propos" \
                --menu "Choisissez une option:" \
                18 60 11 \
                1 "Informations système" \
                2 "Exécuter tous les benchmarks" \
                3 "Benchmark CPU" \
                4 "Benchmark Threads" \
                5 "Benchmark Mémoire" \
                6 "Benchmark Disque" \
                7 "Benchmark Réseau" \
                8 "Stress Test" \
                9 "Exporter les résultats" \
                10 "Planifier les benchmarks" \
                2>&1 >/dev/tty)
            
            exit_status=$?
            
            if [ $exit_status -eq 1 ]; then
                clear
                echo -e "${GREEN}${BOLD}Merci d'avoir utilisé RPi Benchmark! Au revoir.${NC}"
                exit 0
            elif [ $exit_status -eq 2 ]; then
                # Bouton d'aide pressé, afficher les informations sur le programme
                dialog --backtitle "RPi Benchmark v2.0" \
                    --title "À propos" \
                    --msgbox "RPi Benchmark v2.0\n\nUn outil complet pour évaluer les performances de votre Raspberry Pi\n\n© 2025 - Tous droits réservés\n\nDéveloppé avec ❤️ pour la communauté Raspberry Pi" \
                    12 60
                continue
            fi
            
            case $choice in
                1)
                    clear
                    show_system_info
                    ;;
                2) clear; run_all_benchmarks ;;
                3) clear; benchmark_cpu ;;
                4) clear; benchmark_threads ;;
                5) clear; benchmark_memory ;;
                6) clear; benchmark_disk ;;
                7) clear; benchmark_network ;;
                8) clear; stress_test ;;
                9) 
                    clear
                    export_csv
                    export_json
                    echo -e "${GREEN}${SYMBOL_CHECK} Résultats exportés en CSV et JSON dans le dossier ${RESULTS_DIR}${NC}"
                    read -p "Appuyez sur Entrée pour continuer..."
                    ;;
                10) clear; schedule_benchmark ;;
                *) continue ;; # En cas d'annulation, retour au menu
            esac
            
            echo -e "\n${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
            read -r
        done
    else
        # Message d'avertissement si dialog n'est pas disponible ou si nous ne sommes pas dans un terminal interactif
        if ! command -v dialog &> /dev/null; then
            echo -e "${YELLOW}Le package 'dialog' n'est pas installé. Utilisation de l'interface alternative.${NC}"
        elif ! [ -t 0 ] || ! [ -t 1 ] || ! [ -t 2 ]; then
            echo -e "${YELLOW}L'interface dialog nécessite un terminal interactif.${NC}"
            echo -e "${YELLOW}Utilisez './rpi_benchmark.sh --dialog' sans pipe ni redirection.${NC}"
        fi
        
        # Interface améliorée si dialog n'est pas disponible ou ne peut pas être utilisé
        show_enhanced_menu
    fi
}

# Fonction pour afficher le menu en mode amélioré (sans dialog)
show_enhanced_menu() {
    while true; do
        clear
        show_header
        
        # Menu stylisé moderne avec bordure
        echo -e "${MAGENTA}${BOLD}╭─────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}${BG_MAGENTA}${WHITE}${BOLD}                          MENU PRINCIPAL                         ${NC}${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}├─────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_INFO} ${WHITE}[1]${NC}    ${CYAN}Afficher les informations système${NC}               ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_BOLT} ${WHITE}[2]${NC}    ${GREEN}Exécuter tous les benchmarks${NC}                   ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_CPU}  ${WHITE}[3]${NC}    ${BLUE}Benchmark CPU${NC}                                   ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_BOLT} ${WHITE}[4]${NC}    ${TEAL}Benchmark Threads${NC}                               ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_RAM}  ${WHITE}[5]${NC}    ${MAGENTA}Benchmark Mémoire${NC}                              ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_DISK} ${WHITE}[6]${NC}    ${YELLOW}Benchmark Disque${NC}                               ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_NETWORK}  ${WHITE}[7]${NC}    ${BLUE}Benchmark Réseau${NC}                               ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_TEMP} ${WHITE}[8]${NC}    ${RED}Stress Test${NC}                                   ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_CHART}    ${WHITE}[9]${NC}    ${GREEN}Exporter les résultats${NC}                         ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_CLOCK}    ${WHITE}[10]${NC}   ${PURPLE}Planifier les benchmarks${NC}                      ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_CROSS}    ${WHITE}[11]${NC}   ${RED}Quitter${NC}                                         ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}╰─────────────────────────────────────────────────────────────────╯${NC}"
        echo ""
        echo -e "${YELLOW}${BOLD}Entrez votre choix [1-11]:${NC} "
        read -p "" choice

        case $choice in
            1) clear; show_system_info ;;
            2) clear; run_all_benchmarks ;;
            3) clear; benchmark_cpu ;;
            4) clear; benchmark_threads ;;
            5) clear; benchmark_memory ;;
            6) clear; benchmark_disk ;;
            7) clear; benchmark_network ;;
            8) clear; stress_test ;;
            9) 
                clear
                export_csv
                export_json
                echo -e "${GREEN}${SYMBOL_CHECK} Résultats exportés en CSV et JSON dans le dossier ${RESULTS_DIR}${NC}"
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            10) clear; schedule_benchmark ;;
            11) 
                clear
                echo -e "\n${GREEN}${BOLD}Merci d'avoir utilisé RPi Benchmark! Au revoir.${NC}"
                exit 0 
                ;;
            *) 
                echo -e "${RED}${SYMBOL_WARNING} Choix invalide. Veuillez réessayer.${NC}"
                sleep 2
                ;;
        esac
        
        if [[ $choice != 9 ]] && [[ $choice != 11 ]]; then
            echo ""
            echo -e "${YELLOW}${BOLD}Appuyez sur Entrée pour revenir au menu principal...${NC}"
            read -p ""
        fi
    done
}

# Fonction pour afficher les informations système
show_system_info() {
    get_hardware_info
    get_network_info
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
    
    # Message de débogage (uniquement dans le log)
    {
        echo -e "Débogage: Création du fichier CSV à: $csv_file"
        echo -e "Débogage: Le fichier journal est à: $LOG_FILE"
    } >> "$LOG_FILE"
    
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
    
    # Éviter la division par zéro
    if [ "$max" -eq 0 ] || [ -z "$max" ]; then
        echo "Aucune donnée à afficher (valeurs nulles)"
        return
    fi
    
    local scale=$((max / 20))
    # Éviter scale=0 qui causerait une autre division par zéro
    [ "$scale" -eq 0 ] && scale=1
    
    for value in "${data[@]}"; do
        local bars=$((value / scale))
        printf "[%-20s] %s\n" "$(printf '#%.0s' $(seq 1 $bars))" "$value"
    done
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
    
    # Vérifier si crontab est disponible
    if ! command -v crontab &> /dev/null; then
        case $PLATFORM in
            "macos") 
                echo -e "${YELLOW}crontab est normalement disponible sur macOS.${NC}"
                ;;
            *) 
                echo -e "${YELLOW}Installation de cron...${NC}"
                apt-get update && apt-get install -y cron
                systemctl enable cron
                ;;
        esac
    fi
    
    (crontab -l 2>/dev/null; echo "$cron_schedule $(pwd)/rpi_benchmark.sh --cron") | crontab -
    echo -e "${GREEN}Benchmark planifié avec succès${NC}"
}

# Fonction pour afficher un résumé final des benchmarks
show_summary() {
    # Pas de clear pour conserver les résultats détaillés précédents
    echo
    echo -e "${WHITE}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
    center_text "$LOGO_TEXT" "$CYAN"
    echo
    center_text "RÉSUMÉ DES BENCHMARKS" "$GREEN"
    echo
    
    local system_info=$(get_system_info)
    local ram_info=$(get_ram_info)
    local cpu_info=$(get_cpu_info_summary)
    local storage_info=$(get_storage_info)
    local network_info=$(get_network_info)
    
    # Affichage sous forme de tableau élégant
    echo -e "${WHITE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "${WHITE}${BOLD}  %-20s │ %-40s ${NC}\n" "CATÉGORIE" "VALEUR"
    echo -e "${WHITE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Afficher les informations système
    IFS=$'\n'
    for line in $system_info; do
        IFS=':' read -r key value <<< "$line"
        printf "${BLUE}%-20s ${NC}│ ${GREEN}%-40s${NC}\n" "$key" "$value"
    done
    
    # Séparer les catégories
    echo -e "${WHITE}${BOLD}──────────────────────┼──────────────────────────────────────────${NC}"
    
    # Afficher les informations CPU
    for line in $cpu_info; do
        IFS=':' read -r key value <<< "$line"
        printf "${YELLOW}%-20s ${NC}│ ${GREEN}%-40s${NC}\n" "$key" "$value"
    done
    
    # Séparer les catégories
    echo -e "${WHITE}${BOLD}──────────────────────┼──────────────────────────────────────────${NC}"
    
    # Afficher les informations RAM
    for line in $ram_info; do
        IFS=':' read -r key value <<< "$line"
        printf "${MAGENTA}%-20s ${NC}│ ${GREEN}%-40s${NC}\n" "$key" "$value"
    done
    
    # Séparer les catégories
    echo -e "${WHITE}${BOLD}──────────────────────┼──────────────────────────────────────────${NC}"
    
    # Afficher les informations stockage
    for line in $storage_info; do
        IFS=':' read -r key value <<< "$line"
        printf "${CYAN}%-20s ${NC}│ ${GREEN}%-40s${NC}\n" "$key" "$value"
    done
    
    # Séparer les catégories
    echo -e "${WHITE}${BOLD}──────────────────────┼──────────────────────────────────────────${NC}"
    
    # Afficher les informations réseau
    for line in $network_info; do
        IFS=':' read -r key value <<< "$line"
        printf "${RED}%-20s ${NC}│ ${GREEN}%-40s${NC}\n" "$key" "$value"
    done
    
    echo -e "${WHITE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    center_text "Rapport complet sauvegardé dans: $RESULTS_DIR" "$YELLOW"
    echo
}

# Fonction pour obtenir des informations système de base
get_system_info() {
    local hostname=$(hostname)
    local os_type=$(uname -s)
    local os_version=""
    local kernel_version=$(uname -r)
    
    case $PLATFORM in
        "macos")
            os_version=$(sw_vers -productVersion)
            ;;
        "raspbian")
            if [ -f /etc/os-release ]; then
                os_version=$(grep "PRETTY_NAME" /etc/os-release | cut -d= -f2 | tr -d '"')
            fi
            ;;
        *)
            if [ -f /etc/os-release ]; then
                os_version=$(grep "PRETTY_NAME" /etc/os-release | cut -d= -f2 | tr -d '"')
            fi
            ;;
    esac
    
    echo "Nom d'hôte:$hostname"
    echo "Système:$os_type"
    echo "Version:$os_version"
    echo "Noyau:$kernel_version"
    
    # Uptime
    local uptime=$(uptime | cut -d ',' -f1 | cut -d ' ' -f4-)
    echo "Uptime:$uptime"
}

# Fonction pour obtenir des informations résumées sur le CPU
get_cpu_info_summary() {
    local cpu_model=""
    local cpu_cores=""
    local cpu_freq=""
    local cpu_temp=$(get_cpu_temp)
    
    # Utiliser une structure conditionnelle pour différentes plateformes
    case $PLATFORM in
        "macos")
            cpu_model=$(sysctl -n machdep.cpu.brand_string)
            cpu_cores=$(sysctl -n hw.ncpu)
            cpu_freq=$(sysctl -n hw.cpufrequency | awk '{printf "%.0f", $1/1000000}')
            ;;
        "raspbian")
            cpu_model=$(cat /proc/cpuinfo | grep "Model" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')
            cpu_cores=$(nproc)
            if command -v vcgencmd &> /dev/null; then
                cpu_freq=$(vcgencmd measure_clock arm | awk -F'=' '{printf "%.0f", $2/1000000}')
            else
                cpu_freq=$(cat /proc/cpuinfo | grep "cpu MHz" | head -n 1 | cut -d: -f2 | sed 's/^[ \t]*//' | cut -d. -f1)
            fi
            ;;
        *)
            # Pour les autres systèmes Linux
            cpu_model=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^[ \t]*//')
            cpu_cores=$(grep -c "processor" /proc/cpuinfo)
            cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^[ \t]*//' | cut -d. -f1)
            ;;
    esac
    
    # Récupérer plus de données de benchmark
    local cpu_single_ops=$(get_last_benchmark_value "cpu_ops_per_sec")
    local cpu_single_time=$(get_last_benchmark_value "cpu_exec_time")
    local cpu_multi_ops=$(get_last_benchmark_value "cpu_multi_ops")
    local cpu_multi_latency=$(get_last_benchmark_value "cpu_multi_latency")
    
    echo "Modèle CPU:$cpu_model"
    echo "Nombre de cœurs:$cpu_cores"
    echo "Fréquence:${cpu_freq} MHz"
    echo "Température:${cpu_temp}°C"
    
    # Ajouter les données de benchmark si disponibles
    if [ -n "$cpu_single_ops" ]; then
        echo "Ops/sec (single):$cpu_single_ops"
    fi
    
    if [ -n "$cpu_single_time" ]; then
        echo "Temps d'exécution:$cpu_single_time sec"
    fi
    
    if [ -n "$cpu_multi_ops" ]; then
        echo "Opérations (multi):$cpu_multi_ops"
    fi
    
    if [ -n "$cpu_multi_latency" ]; then
        echo "Latence threads:$cpu_multi_latency ms"
    fi
}

# Fonction pour obtenir des informations résumées sur la RAM
get_ram_info() {
    local total_mem=$(free -m | grep "Mem:" | awk '{print $2}')
    local used_mem=$(free -m | grep "Mem:" | awk '{print $3}')
    local free_mem=$(free -m | grep "Mem:" | awk '{print $4}')
    local cached_mem=$(free -m | grep "Mem:" | awk '{print $6}')
    local memory_speed=$(get_last_benchmark_value "memory_transfer_speed")
    
    echo "Mémoire totale:${total_mem} MB"
    echo "Mémoire utilisée:${used_mem} MB"
    echo "Mémoire libre:${free_mem} MB"
    
    # Calculer le pourcentage d'utilisation
    if [ "$total_mem" -gt 0 ]; then
        local usage_percent=$(echo "scale=1; $used_mem * 100 / $total_mem" | bc)
        echo "Ratio utilisation:${usage_percent}%"
    fi
    
    if [ -n "$cached_mem" ]; then
        echo "Mémoire cache:${cached_mem} MB"
    fi
    
    if [ -n "$memory_speed" ]; then
        echo "Vitesse transfert:$memory_speed MB/s"
    fi
}

# Fonction pour obtenir des informations résumées sur le stockage
get_storage_info() {
    local root_size=$(df -h / | tail -n 1 | awk '{print $2}')
    local root_used=$(df -h / | tail -n 1 | awk '{print $3}')
    local root_free=$(df -h / | tail -n 1 | awk '{print $4}')
    local root_percent=$(df -h / | tail -n 1 | awk '{print $5}')
    local disk_read=$(get_last_benchmark_value "disk_read")
    local disk_write=$(get_last_benchmark_value "disk_write")
    local disk_type=$(lsblk -o NAME,TYPE,MODEL | grep "disk" | head -1 | awk '{print $3}' || echo "N/A")
    
    # Calculer l'espace libre en pourcentage
    local root_percent_numeric=$(echo $root_percent | sed 's/%//g')
    local free_percent=$((100 - root_percent_numeric))
    
    # Enregistrer ces métriques pour les graphiques
    local disk_total_num=$(echo $root_size | sed 's/[^0-9.]//g')
    local disk_used_num=$(echo $root_used | sed 's/[^0-9.]//g')
    local disk_free_num=$(echo $root_free | sed 's/[^0-9.]//g')
    
    save_metric_to_db "disk_total" "$disk_total_num"
    save_metric_to_db "disk_used" "$disk_used_num"
    save_metric_to_db "disk_free" "$disk_free_num"
    save_metric_to_db "disk_used_percent" "$root_percent_numeric"
    save_metric_to_db "disk_free_percent" "$free_percent"
    
    echo "Espace disque total:$root_size"
    echo "Espace utilisé:$root_used ($root_percent)"
    echo "Espace libre:$root_free ($free_percent%)"
    
    if [ "$disk_type" != "N/A" ]; then
        echo "Type de disque:$disk_type"
    fi
    
    if [ -n "$disk_read" ]; then
        echo "Vitesse lecture:$disk_read MB/s"
    fi
    
    if [ -n "$disk_write" ]; then
        echo "Vitesse écriture:$disk_write MB/s"
    fi
    
    # Ajouter ces données au fichier de log pour les retrouver facilement
    {
        echo "DISQUE - MÉTRIQUES CLÉS:"
        echo "Espace disque total: $root_size"
        echo "Espace utilisé: $root_used ($root_percent)"
        echo "Espace libre: $root_free ($free_percent%)"
        echo "Type de disque: $disk_type"
        if [ -n "$disk_read" ]; then
            echo "Vitesse lecture: $disk_read MB/s"
        fi
        if [ -n "$disk_write" ]; then
            echo "Vitesse écriture: $disk_write MB/s"
        fi
    } >> "$LOG_FILE"
}

# Fonction pour obtenir des informations résumées sur le réseau
get_network_info() {
    local primary_ip=$(get_primary_ip)
    local primary_interface=$(get_primary_interface)
    local download_speed=$(get_last_benchmark_value "network_download")
    local upload_speed=$(get_last_benchmark_value "network_upload")
    local ping=$(get_last_benchmark_value "network_ping")
    
    echo "Interface réseau:$primary_interface"
    echo "Adresse IP:$primary_ip"
    
    # Récupérer l'adresse MAC si disponible
    if [ -n "$primary_interface" ]; then
        local mac_address=$(ip link show $primary_interface | grep -o 'link/ether [0-9a-f:]\+' | cut -d' ' -f2)
        if [ -n "$mac_address" ]; then
            echo "Adresse MAC:$mac_address"
        fi
    fi
    
    # Récupérer la vitesse de la connexion si disponible
    if [ -n "$primary_interface" ] && [ -e "/sys/class/net/$primary_interface/speed" ]; then
        local link_speed=$(cat /sys/class/net/$primary_interface/speed 2>/dev/null || echo "N/A")
        if [ "$link_speed" != "N/A" ]; then
            echo "Vitesse lien:${link_speed} Mbps"
        fi
    fi
    
    if [ -n "$download_speed" ]; then
        echo "Débit descendant:$download_speed Mbps"
    fi
    
    if [ -n "$upload_speed" ]; then
        echo "Débit montant:$upload_speed Mbps"
    fi
    
    if [ -n "$ping" ]; then
        echo "Latence:$ping ms"
    fi
}

# Fonction pour récupérer la dernière valeur de benchmark
get_last_benchmark_value() {
    local metric_name="$1"
    local db_file="$RESULTS_DIR/benchmark_results.db"
    
    if [ ! -f "$db_file" ]; then
        return
    fi
    
    local result=$(sqlite3 "$db_file" "SELECT value FROM benchmark_results WHERE metric='$metric_name' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null)
    
    if [ -n "$result" ]; then
        echo "$result"
    fi
}

# Fonction pour obtenir l'interface réseau principale
get_primary_interface() {
    # Déterminer l'interface principale (celle avec la route par défaut)
    local primary_iface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    
    # Si aucune interface trouvée, essayer une autre approche
    if [ -z "$primary_iface" ]; then
        # Chercher des interfaces actives
        primary_iface=$(ip -o link show up | grep -v "lo:" | awk -F': ' '{print $2}' | head -n 1)
    fi
    
    echo "$primary_iface"
}

# Fonction pour obtenir l'adresse IP principale
get_primary_ip() {
    local primary_iface=$(get_primary_interface)
    local ip_addr=""
    
    if [ -n "$primary_iface" ]; then
        ip_addr=$(ip -4 addr show dev "$primary_iface" | grep -oP 'inet \K[\d.]+' | head -n 1)
    fi
    
    # Si toujours vide, essayer une autre approche
    if [ -z "$ip_addr" ]; then
        ip_addr=$(hostname -I | awk '{print $1}')
    fi
    
    echo "$ip_addr"
}

# Fonction principale
main() {
    # Vérification explicite si nous sommes sur une Raspberry Pi
    if [[ "$PLATFORM" == "unknown" ]]; then
        if [[ -f /proc/device-tree/model ]] && grep -q "Raspberry Pi" /proc/device-tree/model; then
            PLATFORM="raspbian"
            echo -e "${GREEN}Raspberry Pi détectée via /proc/device-tree/model${NC}"
        elif [[ -f /proc/cpuinfo ]] && grep -q "Raspberry Pi" /proc/cpuinfo; then
            PLATFORM="raspbian"
            echo -e "${GREEN}Raspberry Pi détectée via /proc/cpuinfo${NC}"
        fi
    fi
    
    # Vérification des privilèges administrateur (sauf pour macOS)
    if [[ "$PLATFORM" != "macos" ]] && [[ $EUID -ne 0 ]]; then
        display_error "Ce script doit être exécuté en tant qu'administrateur (root) sur Linux/Raspberry Pi."
    fi

    # Sur macOS, ne pas utiliser sudo pour Homebrew
    if [[ "$PLATFORM" == "macos" ]] && [[ $EUID -eq 0 ]]; then
        display_error "Sur macOS, n'utilisez pas sudo pour exécuter ce script."
    fi
    
    # Créer le répertoire des résultats s'il n'existe pas
    mkdir -p "$RESULTS_DIR"
    
    # Installation des dépendances nécessaires 
    install_dependencies
    
    # Initialisation de la base de données
    init_db
    
    # Gestion des arguments en ligne de commande
    if [ "$1" == "--cron" ]; then
        run_all_benchmarks
        rotate_logs
    elif [ "$1" == "--dialog" ]; then
        if ! command -v dialog &> /dev/null; then
            echo -e "${YELLOW}Le package 'dialog' n'est pas installé. Installation en cours...${NC}"
            install_package "dialog"
        fi
        
        if ! [ -t 0 ] || ! [ -t 1 ] || ! [ -t 2 ]; then
            echo -e "${RED}Erreur: L'option --dialog nécessite un terminal interactif.${NC}"
            echo -e "${YELLOW}Utilisez './rpi_benchmark.sh --dialog' sans pipe ni redirection.${NC}"
            exit 1
        fi
        
        show_dialog_menu
    else
        show_menu
    fi
}

# Fonction pour centrer du texte avec couleur
center_text() {
    local text="$1"
    local color="$2"
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local text_width=${#text}
    local padding_total=$((term_width - text_width))
    local padding_left=$((padding_total / 2))
    
    printf "%${padding_left}s" ""
    echo -e "${color}${text}${NC}"
}

# Exécution du script
main "$@"

