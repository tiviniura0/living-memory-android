# Audit de reprise

Source réellement clonée : branche V1.1 existante `89de7bd6`, descendante de `0f95b7eb` (V1 et main). Aucun changement sur ces deux dernières branches. 18 fichiers changés, 2 124 insertions / 40 suppressions avant cette mission. Pas de fichier AGENTS.md ni de graphe Graphify présent dans ce checkout. Les traces Graphify du rapport précédent sont historiques, pas réexécutées ici.

Le dépôt est un fork volumineux de démonstrations AI Edge. Audit détaillé limité au parcours Living Memory, dépendances Flutter et workflows ; pas de prétention à certifier toutes les démos C++/iOS/web. Fichiers relus : memory_store, auto_memory_store/candidate/engine/panel, gemma_memory_extractor, memory_screen, tests living_memory, rapports existants et build-apk.yml.

Réutilisable : SQLite privé, contrôle du profil d'embedding, requêtes filtrées par agent avant classement, transactions d'import, JSON strict, citation exacte, annulation, revue manuelle, correction réindexée. Les migrations actuelles finissent en user_version=2. Le schéma ne conserve pas les conversations et ne comporte ni FTS5 ni association projet/monde. L'UI est centrée sur l'agent. La recherche n'a qu'un classement vectoriel. Le contrôle de citations avertit mais affiche encore une réponse sans référence.

Risques : SQLite synchrone sur thread UI, clé Android debug pouvant empêcher une mise à jour conservant les données, APK proche de 900 Mo avec les modèles des démos, deux runtimes potentiellement résidents, contradictions fondées sur clés générées et non sur preuve logique, citations pouvant tronquer une négation. La persistance des sessions augmente les données privées locales ; aucune promesse de chiffrement ou d'effacement forensique.

Environnement de reprise : pas de binaire Flutter/Dart local trouvé. Récupération du catalogue officiel Flutter non exploitable dans cet environnement ; utiliser les vrais runners Actions pour les validations Dart, jamais une imitation des tests en Python. Exécution Actions 40478470088 de la branche existante observée en cours lors de l'audit, résultat à vérifier séparément.
