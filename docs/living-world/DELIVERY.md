# Living World AI L1 — livraison expérimentale
Architecture validée : Flutter 2D provisoire, moteur Dart pur, application Android séparée. Branche work/living-world-l1-observable ; base 376ccf33353ec101b1c424b6121eb69ecfc55f62. Aucun merge autorisé.
Les packages de monde n'importent pas Living Memory ; aucune copie de mémoire, migration SQLite ou intégration Gemma. Le mode UI est « Règles locales ».
Fonctions : carte finie 64×64, navigation/zoom, sélection, besoins, ressources réservées, mouvement BFS, pause/vitesse, plafond, checkpoints avec génération précédente, import/export JSON, CLI.
Règles : 4 ticks/s, faim +1 et énergie −1 chaque 40 ticks, repos +4, faim −40 par consommation, collecte 4 ticks, repos 40 ticks, perception Manhattan 6. Pas de naissance, décès, conversation ou construction fonctionnelle.
Sauvegarde : 16 MiB maximum, JSON canonique version 1, SHA-256, manifeste atomique et deux générations ; un fichier orphelin sans manifeste publié n'est pas activé. Corps, RNG, ordre de passage, séquence commandes, actions et événements sont conservés. 10000 événements conservés, vue journal limitée à 500 ; pas de mémoire IA ni d'outbox L2.
La CLI a produit 10000 ticks avec invariants valides et même hash sur deux exécutions ; les mesures Android restent non exécutées. Le SDK/les dépendances sont épinglés par version et lockfile.
Installation et limites de signature : INSTALL_S22.md. Protocole matériel : BENCHMARK.md. Résultats précis : test-report.md et artefacts du run testé.
