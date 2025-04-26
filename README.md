# RPiBenchmark

<div align="center">
  <img src="https://raw.githubusercontent.com/iyotee/rpiBenchmarkV2/main/logo.png" alt="RPiBenchmark Logo" width="400">
</div>

Un script de benchmarking complet pour Raspberry Pi et autres systèmes Linux/macOS.

## 🚀 Fonctionnalités

- 📊 Collecte d'informations système détaillées
- ⚡ Tests de performance CPU, mémoire et disque
- 🌡️ Surveillance de la température
- 📶 Tests de réseau et de bande passante
  - Mesure de latence multi-serveurs (Google, Cloudflare, OpenDNS)
  - Test de débit avec plusieurs méthodes de secours (networkQuality, speedtest-cli, curl)
- 📈 Génération de rapports et graphiques
  - Tableaux formatés avec couleurs pour une meilleure lisibilité
  - Graphiques HTML interactifs avec Chart.js
  - Interface web dynamique pour visualiser l'historique des benchmarks
- 🔄 Tests de stress et de stabilité
- 📅 Planification des benchmarks
- 💾 Exportation des données
  - Format CSV pour l'analyse dans des tableurs
  - Format JSON pour l'intégration avec d'autres outils
  - Base de données SQLite pour le stockage et les requêtes
- 📱 Interfaces utilisateur multiples
  - Interface en ligne de commande (CLI) avec menus intuitifs
  - Interface dialog pour une meilleure expérience visuelle

## 📋 Prérequis

- Raspberry Pi (ou système Linux/macOS)
- Bash 4.0+
- Packages requis (installés automatiquement) :
  - sysbench
  - stress-ng
  - speedtest-cli
  - bc
  - python3
  - sqlite3
  - dialog (pour l'interface dialog)
  - dnsutils (Linux uniquement)
  - hdparm (Linux uniquement)
  - osx-cpu-temp (macOS uniquement, optionnel)

## 🛠️ Installation

```bash
# Cloner le dépôt
git clone https://github.com/iyotee/rpiBenchmarkV2.git
cd rpiBenchmarkV2

# Rendre le script exécutable
chmod +x rpi_benchmark.sh
```

## 💻 Utilisation

```bash
# Exécuter le script avec l'interface CLI standard
./rpi_benchmark.sh

# Exécuter le script avec l'interface dialog
./rpi_benchmark.sh --dialog
```

### Exécution sous Windows avec WSL

Si vous utilisez Windows, vous pouvez exécuter le script via WSL (Windows Subsystem for Linux) :

1. Assurez-vous que WSL est installé avec Ubuntu
2. Utilisez le fichier batch fourni `run_benchmark.bat` pour lancer le script
3. Vous pouvez également tester speedtest-cli directement avec `test_speedtest.bat`

```batch
# Pour exécuter le benchmark complet
run_benchmark.bat

# Pour tester uniquement speedtest-cli
test_speedtest.bat
```

### Interface CLI

Le script propose un menu interactif en ligne de commande avec les options suivantes :
1. Afficher les informations système
2. Exécuter tous les benchmarks
3. Benchmark CPU
4. Benchmark Threads
5. Benchmark Mémoire
6. Benchmark Disque
7. Benchmark Réseau
8. Stress Test
9. Exporter les résultats (CSV et JSON)
10. Planifier les benchmarks
11. Quitter

### Interface Dialog

Une interface plus visuelle utilisant le package dialog, offrant les mêmes fonctionnalités que l'interface CLI mais avec une présentation améliorée.

## 🔧 Options et arguments

Le script accepte plusieurs arguments en ligne de commande :

```bash
# Exécuter en mode automatique (pour crontab)
./rpi_benchmark.sh --cron

# Utiliser l'interface dialog pour une meilleure expérience visuelle
./rpi_benchmark.sh --dialog
```

### Options disponibles :

- `--cron` : Mode non-interactif, exécute tous les benchmarks et exporte les résultats en CSV sans intervention utilisateur. Idéal pour les tâches planifiées.
- `--dialog` : Utilise l'interface dialog pour une navigation plus intuitive dans les menus. Nécessite le package `dialog`.

## 📊 Résultats

Les résultats sont sauvegardés dans le dossier `benchmark_results/` avec :
- Rapports détaillés (fichiers `.log`)
- Fichiers CSV avec l'historique des performances (fichiers `.csv`)
- Fichiers JSON pour une analyse programmatique (fichiers `.json`)
- Graphiques interactifs en HTML (fichiers `.html`)
- Base de données SQLite pour le stockage structuré (fichier `benchmark_history.db`)

### Visualisation des résultats

Le script offre plusieurs façons de visualiser les résultats :
- **Tableaux formatés** : Affichage dans le terminal avec mise en forme et couleurs
- **Graphiques HTML** : Génération de graphiques interactifs avec Chart.js

### Exemples d'utilisation

```bash
# Exécuter un benchmark périodique tous les jours à minuit
(crontab -l 2>/dev/null; echo "0 0 * * * $(pwd)/rpi_benchmark.sh --cron") | crontab -
```

## 📝 Journal des modifications

### v2.0.0
- Support multi-plateforme (Raspberry Pi, Linux, macOS)
- Interface utilisateur améliorée (CLI et dialog)
- Génération de tableaux formatés avec couleurs
- Tests réseau améliorés avec multi-serveurs et méthodes de secours
- Génération de graphiques HTML interactifs
- Planification des benchmarks via crontab
- Export automatique des résultats en CSV et JSON
- Base de données SQLite pour le stockage structuré
- Amélioration de la gestion des erreurs et compatibilité macOS

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Ouvrir une issue pour signaler un bug
- Proposer une pull request pour des améliorations
- Partager vos idées d'amélioration

## 📧 Contact

Pour toute question ou suggestion, n'hésitez pas à ouvrir une issue sur GitHub. 