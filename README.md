# Script de Benchmarking Raspberry Pi v2.0

Ce script permet de réaliser des benchmarks complets sur un Raspberry Pi, en mesurant les performances du CPU, de la mémoire, du disque et du réseau, ainsi que de surveiller la température pendant les tests de charge.

## Fonctionnalités

- Affichage des informations système (hardware et réseau)
- Benchmarks de performance :
  - CPU (single-thread et multi-thread)
  - Mémoire
  - Disque (lecture/écriture)
  - Réseau (débit et latence)
- Stress test avec monitoring de la température
- Interface utilisateur en mode texte avec menu interactif
- Journalisation des résultats dans un fichier log

## Prérequis

Les paquets suivants doivent être installés :

```bash
sudo apt-get update
sudo apt-get install sysbench stress-ng speedtest-cli bc dnsutils
```

## Utilisation

1. Rendez le script exécutable :
```bash
chmod +x rpi_benchmark.sh
```

2. Exécutez le script :
```bash
./rpi_benchmark.sh
```

3. Utilisez le menu interactif pour sélectionner les tests à effectuer.

## Options du menu

1. Afficher les informations système
2. Exécuter tous les benchmarks
3. Benchmark CPU
4. Benchmark Mémoire
5. Benchmark Disque
6. Benchmark Réseau
7. Stress Test
8. Quitter

## Fichiers de log

Les résultats des tests sont enregistrés dans un fichier de log au format :
`benchmark_results_YYYYMMDD_HHMMSS.log`

## Sécurité

- Le script vérifie les dépendances nécessaires avant l'exécution
- Les tests de disque utilisent un fichier temporaire qui est supprimé après les tests
- La température CPU est surveillée pendant les stress tests
- Des alertes sont émises si la température dépasse le seuil critique (70°C par défaut)

## Notes

- Les tests de disque nécessitent suffisamment d'espace libre
- Les tests de réseau nécessitent une connexion Internet active
- Le stress test est configuré pour durer 5 minutes par défaut
- Les résultats sont affichés en temps réel et enregistrés dans le fichier de log

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Signaler des bugs
- Proposer des améliorations
- Ajouter de nouvelles fonctionnalités

## Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails. 