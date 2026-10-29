# Revue V1.4 — suivi des constats

Revue indépendante T1–T4 en lecture seule, base `32dfa547`, head `6812625`.
Aucune validation matérielle ou réussite CI supposée par le reviewer.

| Constat important | Régression / action | Statut courant |
|---|---|---|
| addDocument ouvre BEGIN dans le savepoint de l'ingestion | v14_world : première ingestion réelle ; rendre addDocument imbriquable | Rouge run40757101294 ; vert run40811435881 |
| Missions privées conservées après suppression d'agent | v14_package : suppression A, conservation B ; FK agent_id/cascade | Rouge run40757101294 ; vert run40811435881 |
| Restauration accepte un schéma chiffré incomplet | v14_backup : schéma forgé et objets requis manquants | Rouge run40758608307 ; vert run40759820726 |
| Timeout laisse callback actif mais libère dispatch | v14_extensions : deux callbacks contrôlés par Completer | Rouge run40758608307 ; vert run40759820726 |
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

## Seconde revue ciblée

- Query/document embedding : rouge run40759820726, callback query distinct,
  vert run40811435881 (8tests World).
- Schéma SQL supplémentaire : trigger réactivant une mission et vue inattendue,
  rouges run40811435881. Allowlist canonique stricte et postcondition cancelled
  ajoutées en7b128f2d, en cours de vérification.
- Espaces vides : mapping UI vers personal/no-world reproduit rouge
  run40811435881. Valeurs brutes vides et Unicode conservées en7b128f2d,
  en cours de vérification.
- Widget World : helper d'attente basé sur spinner dans ListView lazy suspect ;
  diagnostic ajouté (compte de reçus et textes visibles), aucune réussite présumée.

Revue finale du diff complet, parcours SAF et compilation encore requis.

## Revue finale indépendante

Une nouvelle revue en lecture seule du diff de mission depuis le merge L1,
head7b128f2d puis delta SAF2d7a9bbe, a vérifié extraction, ACL/reçus concurrents,
grants, timeout, reprise missions, MCP, Skill et hôtes Android.

Constat important neuf : les ACL de publication World survivraient à un restore.
Régression ajoutée en2d7a9bbe avant correction. Le contrat de stockage des droits
sera séparé en namespace générique permission.* ; la restauration retire les
autorisations de sa copie sans toucher aux sources ni au checkpoint actif.

L'observation provisoire d'une clé Keystore liée au chemin a été vérifiée et
retirée : le contrat réel utilise une enveloppe singleton par application.
Point mineur conservé : validation/création des participants du constructeur
World séquentielle ; un paramètre hôte invalide tardif peut laisser un agent vide.
Cet accès n'est pas exposé à un modèle ou à une entrée serveur.

SAF : racine cache canonique corrigée après test source rouge ; le service
répliquant les alias OS reste couvert par une nouvelle régression CI. Les tests
source Kotlin ne sont pas une preuve de sélecteur Android sur appareil.
