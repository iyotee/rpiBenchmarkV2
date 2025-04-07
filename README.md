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
- 📈 Génération de rapports et graphiques
- 🔄 Tests de stress et de stabilité
- 📅 Planification des benchmarks

## 📋 Prérequis

- Raspberry Pi (ou système Linux/macOS)
- Bash 4.0+
- Packages requis (installés automatiquement) :
  - sysbench
  - stress-ng
  - speedtest-cli
  - dnsutils (Linux uniquement)

## 🛠️ Installation

```bash
# Cloner le dépôt
git clone https://github.com/votre-username/rpiBenchmarkV2.git
cd rpiBenchmarkV2

# Rendre le script exécutable
chmod +x rpi_benchmark.sh
```

## 💻 Utilisation

```bash
# Exécuter le script
./rpi_benchmark.sh
```

Le script propose un menu interactif avec les options suivantes :
1. Afficher les informations système
2. Exécuter les benchmarks
3. Effectuer un test de stress
4. Exporter les résultats
5. Planifier un benchmark
6. Quitter

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

### Exemples d'utilisation

```bash
# Exécuter un benchmark périodique tous les jours à minuit
(crontab -l 2>/dev/null; echo "0 0 * * * $(pwd)/rpi_benchmark.sh --cron") | crontab -

# Lancer l'interface web pour visualiser les résultats
./rpi_benchmark.sh
# Puis sélectionner "Interface web" dans le menu
```

## 📝 Journal des modifications

### v2.0.0
- Support multi-plateforme (Raspberry Pi, Linux, macOS)
- Interface utilisateur améliorée
- Génération de graphiques
- Planification des benchmarks
- Export des résultats en CSV

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Ouvrir une issue pour signaler un bug
- Proposer une pull request pour des améliorations
- Partager vos idées d'amélioration

## 📧 Contact

Pour toute question ou suggestion, n'hésitez pas à ouvrir une issue sur GitHub. 