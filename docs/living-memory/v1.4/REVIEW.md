# Revue V1.4 — suivi des constats

Revue indépendante T1–T4 en lecture seule, base `32dfa547`, head `6812625`.
Aucune validation matérielle ou réussite CI supposée par le reviewer.

| Constat important | Régression / action | Statut courant |
|---|---|---|
| addDocument ouvre BEGIN dans le savepoint de l'ingestion | v14_world : première ingestion réelle ; rendre addDocument imbriquable | Rouge confirmé run40757101294 ; correction en validation |
| Missions privées conservées après suppression d'agent | v14_package : suppression A, conservation B ; FK agent_id/cascade | Rouge confirmé run40757101294 ; correction en validation |
| Restauration accepte un schéma chiffré incomplet | v14_backup : schéma forgé et objets requis manquants | Tests ajoutés, correction non déclarée |
| Timeout laisse callback actif mais libère dispatch | v14_extensions : deux callbacks contrôlés par Completer | Tests ajoutés, correction non déclarée |
| Révocation pendant embedding d'une autre instance | v14_world : ACL retirée avant émission du résultat | Test ajouté, correction non déclarée |
| Conflit d'événement entre deux adaptateurs | v14_world : même ID, deux contenus concurrents | Test ajouté, correction non déclarée |

Points reconnus : extraction canonique avec imports compatibles, contrôle de
portée/perception avant embedding, grants opaques à usage unique liés à des
arguments immuables, sortie de restauration séparée et chiffrée, absence de
rejeu automatique des missions incertaines.

Écart mis à part par cette revue : les tests historiques simulant un downgrade
en réécrivant user_version ne sont pas une preuve d'un chemin de migration
supporté en production. Ils restent dans la suite ; les fixtures doivent
représenter fidèlement leur ancienne version en retirant les nouvelles tables.
UI/T5, APK, S22 et conformité complète MCP hors sous-ensemble déclaré restent à
vérifier séparément. Aucun constat de sécurité ci-dessus n'est reporté comme
simple limitation matérielle.
