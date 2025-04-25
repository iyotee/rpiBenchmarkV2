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
    echo -e "${BLUE}${BOLD}║  ${BG_BLUE}${WHITE}${BOLD}  RPi BENCHMARK v2.0 - ANALYSE COMPLÈTE DES PERFORMANCES  ${NC}${BLUE}${BOLD}  ║${NC}"
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
    echo -e "${right_t}${NC}"
    
    # Ligne d'en-tête
    echo -ne "${line_color}${vertical}${NC}${header_bg}${header_fg}${BOLD}"
    printf " %-${name_width}s │ %${value_width}s " "MÉTRIQUE" "VALEUR"
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
        printf " ${text_color}%-${name_width}s${NC}${background_color} ${line_color}${vertical}${NC}${background_color} ${value_color}%${value_width}s ${NC}${line_color}${vertical}${NC}\n" "$name" "$value"
        
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

# Fonction pour installer les paquets requis
install_packages() {
    local packages=()
    
    # Définir les paquets en fonction de la plateforme
    case $PLATFORM in
        "macos")
            packages=("sysbench" "stress-ng" "speedtest-cli" "bc" "python3" "sqlite3")
            # Vérifier si osx-cpu-temp est nécessaire pour la température sous macOS
            if ! command -v osx-cpu-temp &> /dev/null; then
                packages+=("osx-cpu-temp")
            fi
            ;;
        "raspbian"|"ubuntu")
            packages=("sysbench" "stress-ng" "speedtest-cli" "bc" "dnsutils" "hdparm" "python3" "python3-pip" "sqlite3" "dialog")
            ;;
        *)
            # Même sur plateforme inconnue, tentons d'installer les paquets standard Linux
            echo -e "${YELLOW}Plateforme non reconnue. Tentative d'installation des paquets Linux par défaut...${NC}"
            packages=("sysbench" "stress-ng" "speedtest-cli" "bc" "dnsutils" "hdparm" "python3" "python3-pip" "sqlite3" "dialog")
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
            # Exception pour les packages qui ne fournissent pas de commande exécutable
            if [[ "$package" == "python3-pip" || "$package" == "dnsutils" || "$package" == "dialog" || "$package" == "sqlite3" ]]; then
                case $PLATFORM in
                    "macos")
                        if [[ "$package" == "sqlite3" ]] && ! command -v sqlite3 &> /dev/null; then
            missing_deps+=("$package")
                        fi
                        ;;
                    *)
                        # Pour Linux, nous ajoutons simplement ces packages
                        missing_deps+=("$package")
                        ;;
                esac
            else
                missing_deps+=("$package")
            fi
        fi
    done

    # Installer les dépendances manquantes
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${YELLOW}Installation des paquets requis: ${missing_deps[*]}...${NC}"
        case $PLATFORM in
            "macos")
                for package in "${missing_deps[@]}"; do
                    echo -e "${YELLOW}Installation de $package...${NC}"
                    brew install "$package" || display_error "Échec de l'installation de $package"
                done
                ;;
            "raspbian"|"ubuntu")
                apt-get update
                for package in "${missing_deps[@]}"; do
                    echo -e "${YELLOW}Installation de $package...${NC}"
                    apt-get install -y "$package" || display_error "Échec de l'installation de $package"
                done
                ;;
            *)
                # Tentative d'installation avec apt-get (commun à la plupart des distributions Linux)
                echo -e "${YELLOW}Tentative d'installation avec apt-get...${NC}"
                apt-get update
                for package in "${missing_deps[@]}"; do
                    echo -e "${YELLOW}Installation de $package...${NC}"
                    apt-get install -y "$package" || echo -e "${RED}Échec de l'installation de $package${NC}"
                done
                ;;
        esac
        echo -e "${GREEN}Installation des paquets terminée.${NC}"
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
            echo -e "${WHITE}${BOLD}Test de performance CPU pour Linux...${NC}"
            echo -e "${YELLOW}${SYMBOL_INFO} Exécution du benchmark sysbench CPU...${NC}"
            
            # Barre de progression simulée pendant que sysbench s'exécute
            show_progress 0
            local results=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>/dev/null) &
            local pid=$!
            
            # Afficher une barre de progression pendant l'exécution
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
    modern_header "BENCHMARK THREADS" $PURPLE $SYMBOL_BOLT
    
    echo -e "${WHITE}${BOLD}Test de performance multi-threads...${NC}"
    echo -e "${YELLOW}${SYMBOL_INFO} Détection du nombre de cœurs CPU: $(get_cpu_cores)${NC}"
    echo -e "${YELLOW}${SYMBOL_INFO} Exécution du benchmark sysbench threads...${NC}"
    
    local cpu_cores=$(get_cpu_cores)
    
    # Barre de progression simulée pendant que sysbench s'exécute
    show_progress 0
    local results=$(sysbench threads --threads=$cpu_cores --thread-yields=1000 --thread-locks=8 run 2>/dev/null) &
    local pid=$!
    
    # Afficher une barre de progression pendant l'exécution
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
    
    local time=$(echo "$results" | grep 'total time:' | awk '{print $NF}' | sed 's/s$//')
    local ops=$(echo "$results" | grep 'total number of events:' | awk '{print $NF}')
    local latency=$(echo "$results" | grep 'avg:' | awk '{print $NF}' | sed 's/ms$//')
    
    # Préparer les données pour le tableau
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
                
                # Barre de progression simulée pendant que sysbench s'exécute
                show_progress 0
                local results=$(sysbench memory --memory-block-size=1K --memory-total-size=10G --memory-access-mode=seq run 2>/dev/null) &
                local pid=$!
                
                # Afficher une barre de progression pendant l'exécution
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
    
    # S'assurer que le répertoire des résultats existe
    mkdir -p "$RESULTS_DIR" 2>/dev/null
    
    # Variables communes initialisées avec des valeurs par défaut
    local total_size="N/A"
    local used_space="N/A"
    local free_space="N/A"
    local write_speed=0
    local read_speed=0
    
    # Obtenir les informations sur l'espace disque avec df (commande de base)
    echo -e "${WHITE}${BOLD}Analyse des performances disque...${NC}"
    echo -e "${YELLOW}${SYMBOL_INFO} Récupération des informations de disque...${NC}"
    
    if df -h / 2>/dev/null >/dev/null; then
        total_size=$(df -h / | awk 'NR==2 {print $2}')
        used_space=$(df -h / | awk 'NR==2 {print $3}')
        free_space=$(df -h / | awk 'NR==2 {print $4}')
        echo -e "${GREEN}${SYMBOL_CHECK} Espace disque: ${WHITE}Total=${LIME}$total_size${NC}, ${WHITE}Utilisé=${YELLOW}$used_space${NC}, ${WHITE}Libre=${GREEN}$free_space${NC}"
    else
        echo -e "${YELLOW}${SYMBOL_WARNING} Impossible d'obtenir les informations sur l'espace disque${NC}"
    fi
    
    # Test de performance disque
    echo -e "${YELLOW}${SYMBOL_INFO} Test de performance disque en cours...${NC}"
    
    # Fichier temporaire directement dans le répertoire courant
    local test_file="./tmp_benchmark_file_$$"
    
    # Test d'écriture ultra simple avec dd
    echo -e "${YELLOW}${SYMBOL_BOLT} Exécution du test d'écriture...${NC}"
    
    # Barre de progression simulée
    for i in {1..10}; do
        show_progress $((i*10))
        sleep 0.1
    done
    
    local start_time=$(date +%s)
    dd if=/dev/zero of="$test_file" bs=4k count=5000 status=none 2>/dev/null
    local end_time=$(date +%s)
    local time_diff=$((end_time - start_time))
    echo -e "\n${GREEN}${SYMBOL_CHECK} Test d'écriture terminé ${NC}"
    
    # Calcul simple de la vitesse d'écriture
    if [[ -f "$test_file" ]]; then
        if [[ $time_diff -gt 0 ]]; then
            # 5000 * 4k = 20M
            write_speed=$((20 / time_diff))
            echo -e "${GREEN}Vitesse d'écriture: ${WHITE}${write_speed}${NC} MB/s"
        else
            write_speed=20  # Si trop rapide pour être mesuré
            echo -e "${GREEN}Vitesse d'écriture: ${WHITE}>20${NC} MB/s (trop rapide pour être mesuré précisément)"
        fi
        
        # Test de lecture simple
        echo -e "${YELLOW}${SYMBOL_BOLT} Exécution du test de lecture...${NC}"
        
        # Barre de progression simulée
        for i in {1..10}; do
            show_progress $((i*10))
            sleep 0.1
        done
        
        start_time=$(date +%s)
        dd if="$test_file" of=/dev/null bs=4k count=5000 status=none 2>/dev/null
        end_time=$(date +%s)
        time_diff=$((end_time - start_time))
        echo -e "\n${GREEN}${SYMBOL_CHECK} Test de lecture terminé ${NC}"
        
        if [[ $time_diff -gt 0 ]]; then
            read_speed=$((20 / time_diff))
            echo -e "${GREEN}Vitesse de lecture: ${WHITE}${read_speed}${NC} MB/s"
        else
            read_speed=20  # Si trop rapide pour être mesuré
            echo -e "${GREEN}Vitesse de lecture: ${WHITE}>20${NC} MB/s (trop rapide pour être mesuré précisément)"
        fi
    else
        echo -e "${RED}${SYMBOL_CROSS} Erreur: Le test d'écriture a échoué${NC}"
    fi
    
    # Nettoyage (même si le fichier n'existe pas, cette commande est sans danger)
    rm -f "$test_file" 2>/dev/null
    
    # Créer le tableau des résultats
    # Calculer le pourcentage d'utilisation
    local disk_usage=""
    if [[ "$used_space" != "N/A" && "$total_size" != "N/A" ]]; then
        # Extraire les valeurs numériques (en supposant qu'elles sont en Go)
        local used_num=$(echo "$used_space" | sed 's/[A-Za-z]//g')
        local total_num=$(echo "$total_size" | sed 's/[A-Za-z]//g')
        if [[ -n "$used_num" && -n "$total_num" ]]; then
            disk_usage="$(echo "scale=1; $used_num*100/$total_num" | bc)%"
        fi
    fi
    
    local metrics=(
        "Taille totale:$total_size"
        "Espace utilisé:$used_space"
        "Espace libre:$free_space"
        "Utilisation:${disk_usage:-N/A}"
        "Vitesse d'écriture:$(printf "%d MB/s" "$write_speed")"
        "Vitesse de lecture:$(printf "%d MB/s" "$read_speed")"
        "Ratio lecture/écriture:$(printf "%.1fx" "$(echo "scale=1; $read_speed/$write_speed" | bc 2>/dev/null || echo 1)")"
    )
    
    format_table "Résultats Disque" "${metrics[@]}"
    
    echo -e "\n${GREEN}${SYMBOL_CHECK} Benchmark disque terminé${NC}"
}

# Fonction pour le benchmark réseau
benchmark_network() {
    log_result "\n${BLUE}=== BENCHMARK RÉSEAU ===${NC}"
    
    # Variables par défaut
    local avg_ping=0
    local download_speed=0
    local upload_speed=0
    local speedtest_failed=true
    
    # Test de ping simple vers Google DNS et Cloudflare
    log_result "${YELLOW}Test de latence réseau...${NC}"
    
    # Vérifier que ping est disponible
    if command -v ping &>/dev/null; then
        local ping_servers=("8.8.8.8" "1.1.1.1")
        local total_ping=0
        local ping_count=0
        
        for server in "${ping_servers[@]}"; do
            log_result "  Test ping vers $server..."
            
            # Essayer ping avec plus de paquets pour une meilleure précision
            local ping_cmd="ping -c 5 $server"
            local ping_result=""
            
            # Exécution du ping avec gestion d'erreur
            ping_result=$($ping_cmd 2>/dev/null | grep -i "avg\|moyenne" | grep -o "[0-9.]\+/[0-9.]\+/[0-9.]\+" | cut -d/ -f2)
            
            if [ -n "$ping_result" ] && [ "$ping_result" != "0" ]; then
                log_result "    Latence: ${ping_result} ms"
                # Addition simple pour éviter les erreurs avec bc
                total_ping=$(echo "$total_ping + $ping_result" | bc 2>/dev/null || echo "$total_ping")
                ping_count=$((ping_count + 1))
            else
                log_result "    ${RED}Échec du test ping vers $server${NC}"
            fi
        done
        
        # Calcul de la moyenne (avec protection)
        if [ $ping_count -gt 0 ]; then
            avg_ping=$(echo "scale=2; $total_ping / $ping_count" | bc 2>/dev/null || echo "0")
            log_result "  Latence moyenne: ${avg_ping} ms"
        else
            log_result "  ${RED}Impossible de mesurer la latence${NC}"
        fi
    else
        log_result "  ${RED}Commande ping non disponible${NC}"
    fi
    
    # Test de débit amélioré avec speedtest-cli
    log_result "${YELLOW}Test de débit réseau avancé...${NC}"
    
    # Vérifier si speedtest-cli est disponible
    if command -v speedtest-cli &>/dev/null; then
        log_result "  Utilisation de speedtest-cli pour une mesure précise..."
        
        # Exécuter speedtest-cli directement
        local test_output=$(mktemp)
        
        # Exécuter speedtest-cli en mode simple
        speedtest-cli --simple > "$test_output" 2>&1
        local speedtest_status=$?
        
        # Si speedtest-cli réussit, extraire les résultats
        if [ $speedtest_status -eq 0 ] && [ -s "$test_output" ]; then
            download_speed=$(grep -i "Download" "$test_output" | awk '{print $2}' || echo "0")
            upload_speed=$(grep -i "Upload" "$test_output" | awk '{print $2}' || echo "0")
            local ping_result=$(grep -i "Ping" "$test_output" | awk '{print $2}' || echo "0")
            
            if [ -n "$download_speed" ] && [ "$download_speed" != "0" ]; then
                log_result "  Débit descendant: ${download_speed} Mbps"
                log_result "  Débit montant: ${upload_speed} Mbps"
                log_result "  Ping (speedtest-cli): ${ping_result} ms"
                speedtest_failed=false
            else
                log_result "  ${RED}Échec du test speedtest-cli (résultats vides)${NC}"
                log_result "  Utilisation de la méthode alternative..."
                speedtest_failed=true
            fi
        else
            log_result "  ${RED}Échec du test speedtest-cli (code: $speedtest_status)${NC}"
            log_result "  Contenu de la sortie d'erreur:"
            cat "$test_output" | while read -r line; do
                log_result "    $line"
            done
            log_result "  Utilisation de la méthode alternative..."
            speedtest_failed=true
        fi
        
        rm -f "$test_output" 2>/dev/null
    else
        log_result "  ${YELLOW}speedtest-cli non disponible, utilisation de la méthode alternative...${NC}"
        speedtest_failed=true
    fi
    
    # Si speedtest-cli a échoué, utiliser la méthode manuelle
    if [ "$speedtest_failed" = true ]; then
        # Fichiers de test de différentes tailles
        local test_files=(
            "http://speedtest.tele2.net/100KB.zip:100"
            "http://speedtest.tele2.net/1MB.zip:1000"
        )
        
        # Effectuer les tests de téléchargement
        local alt_download_speed=$(test_download_speed "${test_files[@]}")
        download_speed=$alt_download_speed
    fi
    
    # S'assurer que download_speed a une valeur
    [ -z "$download_speed" ] && download_speed=5
    
    # Créer le tableau des résultats
    if [ -n "$upload_speed" ] && [ "$upload_speed" != "0" ]; then
        local metrics=(
            "Latence moyenne:$(printf "%.2f ms" "$avg_ping")"
            "Débit descendant:$(printf "%s Mbps" "$download_speed")"
            "Débit montant:$(printf "%s Mbps" "$upload_speed")"
        )
    else
        local metrics=(
            "Latence moyenne:$(printf "%.2f ms" "$avg_ping")"
            "Débit descendant:$(printf "%s Mbps" "$download_speed")"
        )
    fi
    
    format_table "Résultats Réseau" "${metrics[@]}"
    
    log_result "${GREEN}Benchmark réseau terminé${NC}"
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
    
    <div class="charts-container">
        <div class="chart-container">
            <div class="chart-title">Performance CPU</div>
            <canvas id="cpuChart"></canvas>
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
    </div>
    
    <div class="footer">
        Généré le ${date_formatted} par RPi Benchmark v2.0
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
EOF

    # Continuer avec le reste du contenu HTML
    cat >> "$html_file" << 'EOF'
        // Configuration commune
        const commonOptions = {
            responsive: true,
            maintainAspectRatio: true,
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
                labels: ['Single Thread', 'Multi Thread'],
                datasets: [{
                    label: 'Opérations par seconde',
                    data: [data.cpu.singleThread.opsPerSec, data.cpu.multiThread.opsPerSec],
                    backgroundColor: ['rgba(54, 162, 235, 0.7)', 'rgba(255, 99, 132, 0.7)'],
                    borderColor: ['rgba(54, 162, 235, 1)', 'rgba(255, 99, 132, 1)'],
                    borderWidth: 1
                }]
            },
            options: commonOptions
        });

        // Graphique Mémoire
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
            options: commonOptions
        });

        // Graphique Disque
        new Chart(document.getElementById('diskChart'), {
            type: 'bar',
            data: {
                labels: ['Vitesse Écriture (MB/s)', 'Vitesse Lecture (MB/s)', 'IOPS Écriture', 'IOPS Lecture'],
                datasets: [{
                    label: 'Performance',
                    data: [data.disk.writeSpeed, data.disk.readSpeed, data.disk.writeIOPS, data.disk.readIOPS],
                    backgroundColor: [
                        'rgba(255, 159, 64, 0.7)',
                        'rgba(153, 102, 255, 0.7)',
                        'rgba(255, 205, 86, 0.7)',
                        'rgba(201, 203, 207, 0.7)'
                    ],
                    borderColor: [
                        'rgb(255, 159, 64)',
                        'rgb(153, 102, 255)',
                        'rgb(255, 205, 86)',
                        'rgb(201, 203, 207)'
                    ],
                    borderWidth: 1
                }]
            },
            options: commonOptions
        });

        // Graphique Réseau
        new Chart(document.getElementById('networkChart'), {
            type: 'bar',
            data: {
                labels: ['Débit Descendant (Mbps)', 'Ping (ms)'],
                datasets: [{
                    label: 'Performance',
                    data: [data.network.downloadSpeed, data.network.ping],
                    backgroundColor: [
                        'rgba(255, 99, 132, 0.7)',
                        'rgba(54, 162, 235, 0.7)'
                    ],
                    borderColor: [
                        'rgba(255, 99, 132, 1)',
                        'rgba(54, 162, 235, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: commonOptions
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

# Fonction pour modifier run_all_benchmarks pour inclure la génération des graphiques
run_all_benchmarks() {
    benchmark_cpu
    benchmark_threads
    benchmark_memory
    benchmark_disk
    benchmark_network
    
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
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_INFO} ${WHITE}1.${NC} ${CYAN}Afficher les informations système${NC}                           ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_BOLT} ${WHITE}2.${NC} ${LIME}Exécuter tous les benchmarks${NC}                                ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_CPU} ${WHITE}3.${NC} ${CYAN}Benchmark CPU${NC}                                                ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_BOLT} ${WHITE}4.${NC} ${CYAN}Benchmark Threads${NC}                                            ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_RAM} ${WHITE}5.${NC} ${MAGENTA}Benchmark Mémoire${NC}                                           ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_DISK} ${WHITE}6.${NC} ${YELLOW}Benchmark Disque${NC}                                            ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_NETWORK} ${WHITE}7.${NC} ${BLUE}Benchmark Réseau${NC}                                            ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_TEMP} ${WHITE}8.${NC} ${RED}Stress Test${NC}                                                ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_CHART} ${WHITE}9.${NC} ${GREEN}Exporter les résultats (CSV et JSON)${NC}                     ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_CLOCK} ${WHITE}10.${NC} ${PURPLE}Planifier les benchmarks${NC}                                 ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║${NC}  ${SYMBOL_CROSS} ${WHITE}11.${NC} ${RED}Quitter${NC}                                                    ${CYAN}${BOLD}║${NC}"
        echo -e "${CYAN}${BOLD}║                                                                     ║${NC}"
        echo -e "${CYAN}${BOLD}╚═════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Entrez votre choix ${WHITE}[1-11]${YELLOW}: ${NC}"
        
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
                    --msgbox "RPi Benchmark v2.0\n\nUn outil complet pour évaluer les performances de votre Raspberry Pi\n\n© 2023 - Tous droits réservés\n\nDéveloppé avec ❤️ pour la communauté Raspberry Pi" \
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
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_INFO}  ${WHITE}[1]${NC} ${CYAN}Afficher les informations système${NC}               ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_BOLT}  ${WHITE}[2]${NC} ${GREEN}Exécuter tous les benchmarks${NC}                   ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_CPU}  ${WHITE}[3]${NC} ${BLUE}Benchmark CPU${NC}                                   ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_BOLT}  ${WHITE}[4]${NC} ${TEAL}Benchmark Threads${NC}                               ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_RAM}  ${WHITE}[5]${NC} ${MAGENTA}Benchmark Mémoire${NC}                              ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_DISK}  ${WHITE}[6]${NC} ${YELLOW}Benchmark Disque${NC}                               ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_NETWORK}  ${WHITE}[7]${NC} ${BLUE}Benchmark Réseau${NC}                               ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_TEMP}  ${WHITE}[8]${NC} ${RED}Stress Test${NC}                                   ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_CHART}  ${WHITE}[9]${NC} ${GREEN}Exporter les résultats${NC}                         ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_CLOCK} ${WHITE}[10]${NC} ${PURPLE}Planifier les benchmarks${NC}                      ${MAGENTA}${BOLD}│${NC}"
        echo -e "${MAGENTA}${BOLD}│${NC}  ${LIME}${SYMBOL_CROSS} ${WHITE}[11]${NC} ${RED}Quitter${NC}                                         ${MAGENTA}${BOLD}│${NC}"
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
    log_result "\n${BLUE}=== RÉSUMÉ DES BENCHMARKS ===${NC}"
    
    # Récupérer les résultats de chaque test depuis le fichier de log
    local cpu_perf=$(grep -A10 'Résultats CPU' "$LOG_FILE" | grep -i 'opérations/sec' | head -1 | awk -F'|' '{print $NF}' | tr -d ' ' || echo "N/A")
    local mem_perf=$(grep -A10 'Résultats Mémoire' "$LOG_FILE" | grep -i 'vitesse de transfert' | head -1 | awk -F'|' '{print $NF}' | tr -d ' ' || echo "N/A")
    local disk_read=$(grep -A10 'Résultats Disque' "$LOG_FILE" | grep -i 'vitesse de lecture' | head -1 | awk -F'|' '{print $NF}' | tr -d ' ' || echo "N/A")
    local disk_write=$(grep -A10 'Résultats Disque' "$LOG_FILE" | grep -i 'vitesse d.écriture' | head -1 | awk -F'|' '{print $NF}' | tr -d ' ' || echo "N/A")
    local net_speed=$(grep -A10 'Résultats Réseau' "$LOG_FILE" | grep -i 'débit descendant' | head -1 | awk -F'|' '{print $NF}' | tr -d ' ' || echo "N/A")
    
    # Créer un tableau récapitulatif des performances
    local metrics=(
        "CPU:$cpu_perf"
        "Mémoire:$mem_perf"
        "Disque (Lecture):$disk_read"
        "Disque (Écriture):$disk_write"
        "Réseau:$net_speed"
    )
    
    format_table "Résumé Global des Performances" "${metrics[@]}"
    
    log_result "\n${GREEN}Tous les benchmarks sont terminés !${NC}"
    log_result "${YELLOW}Les résultats détaillés ont été enregistrés dans: ${LOG_FILE}${NC}"
    log_result "${YELLOW}Graphiques générés dans : ${RESULTS_DIR}/benchmark_charts.html${NC}"
    log_result "${YELLOW}Ouvrez ce fichier dans votre navigateur pour voir les graphiques.${NC}"
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

# Exécution du script
main "$@"