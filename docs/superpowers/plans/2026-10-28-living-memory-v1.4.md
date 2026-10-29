# Living Memory V1.4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [x]`) syntax for tracking. Parallel work is limited to disjoint extension and backup modules; one fresh whole-branch reviewer at completion.

**Goal:** Relier réellement les modules L1 existants à la mémoire canonique et livrer les extensions Android V1.4 avec preuves.

**Architecture:** Le core de stockage est extrait sans copie en package Dart. Un adaptateur séparé implémente le MemoryPort de L1. Les extensions n'accordent aucun droit au texte généré et restent désactivées sans geste utilisateur.

**Tech Stack:** Dart/Flutter 3.47.3, SQLite3 3.7.1 / SQLCipher, Android Keystore, packages World L1 existants.

**Spec:** `docs/superpowers/specs/2026-10-28-living-memory-v1.4-design.md`, addendum approuvé par le message de Tivini.

## Global Constraints

- Conserver applicationId, données, profil EmbeddingGemma 2/768, Gemma E2B/E4B, RAG et Auto-Memory.
- Le core mémoire ne dépend ni de simulation ni de Flutter ; World Core ne dépend pas du moteur mémoire.
- Aucun accès interapplications à une base privée, aucune clé de production créée, aucun secret dans Git.
- Aucun service payant, serveur, shell d'agent, déploiement PC/VPS ou monde avancé.
- Contrats V1 ; inconnus/arguments non autorisés refusés avant effet ; tâches bornées et aucune réactivation de grants après restauration.
- TDD : tests écrits puis exécutés rouges, implémentation minimale, verts ; preuve CI si SDK local indisponible.
- Préserver les sources d'audit V1.3.1 et les modules L1 ; réexaminer le diff concerné seulement.

## Review Focus

1. Un événement non perçu ne doit jamais être livré à un agent ni une autre portée.
2. Un rejeu après crash ne doit pas dupliquer une source ou réappliquer un outil sensible.
3. Un manifeste/argument modifié après accord doit être refusé.
4. Une restauration malformée ne doit pas écraser la base ouverte ou réactiver des missions.
5. Une migration/extraction doit conserver FTS, index, clés et imports historiques.

## Préflight et méthode

Exécution native choisie pour réduire les contextes, revue indépendante finale.
Tivini autorise explicitement plan puis implémentation sans nouvelle validation
des choix couverts. Le journal `docs/living-memory/v1.4/PROGRESS.md` est la référence
de reprise. Les deux documents Library sont des références, pas des sources à
publier intégralement dans le dépôt public. L1 est fusionné avec ses commits.

| Producteur → consommateur | Contrat partagé | Vérification avant tâche |
|---|---|---|
| T1 → T2/T3/T4 | MemoryStore et MemoryScope, exports historiques | Même identité de types ; aucune seconde base personnelle |
| T2 → T5 | MemoryPort et WorldSnapshot existants | worldId/agentId et perception L1 conservés |
| T3 → T5 | invoke et permissions | Scope fixé par hôte ; pas par le modèle |
| T4 → T5 | export/restore vers fichier séparé | Base active conservée ; aucune permission restaurée active |
| T5 → T6 | UI et workflows | Version, SHA, tests et APK sur même arbre |

### Task 1: Extraction canonique et chaîne de preuve

**Files:** créer `packages/living_memory_core/{pubspec.yaml,lib/living_memory_core.dart,lib/src/*}` ; remplacer par exports les fichiers historiques memory_store, encrypted_database, auto_memory_candidate et module_contracts ; parts déplacés avec leur library. Modifier pubspec sample et workflow V1.4.

**Interfaces:** produire les mêmes `MemoryStore.open`, `MemoryChunk`, `AutoMemoryCandidate`, `MemoryScope` ; aucun changement de schéma à cette tâche.

- [x] Écrire `test/living_memory/v14_package_test.dart` : importer le nouveau package et l'ancien chemin, vérifier `identical` du type et ajout/recherche/reopen réel ; import manquant attendu rouge.
- [x] Exécuter la CI ciblée avant extraction ; conserver lien/log rouge.
- [x] Déplacer la source canonique (pas la recopier), ajouter wrappers export et dépendance path.
- [x] Vérifier tests ciblés puis suite mémoire historique ; vérifier aucun import world dans le core.
- [x] Commit `refactor: extract canonical memory core with compatibility exports`.

### Task 2: Adaptateur World L1 et mémoire persistante

**Files:** créer `packages/living_world_memory`, `test/world_memory_test.dart` ; modifier core `src/extension_store.dart` (part de memory_store), migrations et gardes de schéma.

**Interfaces:** `LivingWorldMemory implements MemoryPort`, construit avec MemoryStore, embedding async et contexte hôte autorisé ; `ingest`, `recall`, `delete`, `health`. `ingestSnapshot(WorldSnapshot)` ne livre que `observedBy` et ne change jamais l'état WorldCore. SourceId et idempotence stockés avec provenance. Partage par publication à destinataires nommés ; pas de recherche globale.

- [x] Tests : même ID/contenu idempotent, conflit refusé, perception de A absente chez B, monde étranger refusé, deux agents qualifiés via memoryAgentKey, partage/révocation, suppression, reopen SQLCipher.
- [x] Test d'intégration : vrais WorldCore/SimulationRunner, sauvegarde CheckpointStore, ingestion après checkpoint, retry après reopen et souvenir cité consultable ; l'événement garde son tick et sa provenance simulée.
- [x] Exécuter rouge en CI ; implémenter migration additive 4→5 (tables d'extensions uniquement), refus version future avant écriture.
- [x] Exécuter vert et suites de migrations/FTS V1.3.1 ; commit `feat: connect existing world events to scoped persistent memory`.

### Task 3: Permissions, Tools, Skills, plugins, MCP et missions

**Files:** `packages/living_memory_extensions/lib/{living_memory_extensions.dart,src/*}`, tests correspondants ; adaptation catalogue Skills existant côté sample.

**Interfaces:** requête immuable versionnée ; gestionnaire local de grants opaque et consommable ; registre d'adaptateurs ; manifeste strict avec empreinte ; `McpClient` sortant avec transport injecté ; file `MissionQueue` persistante avec `runDue`, `cancel`, états bornés et reprise indeterminate.

- [x] Tests rouges : forgery/rejeu/expiration/scope/argument modifié, plugin changé, outil inconnu ; aucune I/O sur refus.
- [x] Tests rouges MCP avec serveur loopback : JSON/SSE, ids/protocole, réponse trop grosse, délai, redirection, endpoint non approuvé ; aucune requête sans configuration.
- [x] Tests missions : reopen, échéance, max8 étapes, annulation, crash running→indeterminate, effet incertain jamais rejoué.
- [x] Implémenter le minimum. SKILL.md reste instruction sans droit ; parser de l'app réutilisé, pas de chargement JS.
- [x] Tests verts puis commit `feat: add permission gated extensions and persistent missions`.

### Task 4: Export/restauration chiffrés et signature

**Files:** `packages/living_memory_core/lib/src/memory_backup.dart`, tests dans sample ; procédure V1.4 référençant SIGNING V1.3.1.

**Interfaces:** export SQLCipher vers fichier neuf avec clé de récupération aléatoire ; restore vers fichier séparé avec validation profil/schéma/intégrité. API ne remplace jamais la base active. Clé Keystore non exportée.

- [x] Tests rouges : roundtrip chiffré, mauvaise clé, troncature, collision de destination, schéma futur, source active inchangée et restauration permissions désactivées.
- [x] Implémenter avec source SQLCipher ouverte et transactions compatibles ; fermer toutes connexions temporaires sur erreur.
- [x] Tests verts et tests sécurité V1.3.1 ; garder le refus release sans signature externe et l'opt-in expérimental explicite.
- [x] Commit `feat: prepare verified encrypted memory transfers without replacing active data`.

### Task 5: Branchement Android et parcours vérifiable

**Files:** sample `living_memory/extensions_panel.dart`, `world_memory_panel.dart`, `memory_screen.dart`, pubspec/version ; tests widgets.

**Interfaces:** hôte ouvre ses stores avec MemoryKey existant, embarque le core L1 sans copier sa logique, affiche mémoire privée/partagée par agent, gestes de publication/autorisation et missions. Aucun accès aux outils téléphone par les habitants.

- [x] Tests rouges : navigation, deux agents, souvenir partagé après geste, état de mission et erreurs explicites.
- [x] Raccorder aux services réels d'embedding/génération existants, avec mode de règle local clairement étiqueté si modèle absent. Aucun faux modèle fourni dans le produit.
- [x] Export/import via SAF avec clé séparée, validation sans activation destructive ; protocole de reprise documenté.
- [x] Tests verts, format/analyse ; commit `feat: expose integrated world memory and extension controls`.

### Task 6: Revue, régressions et livraison

**Files:** workflows V1.4 et `docs/living-memory/v1.4/{REPORT,BUILD,REVIEW,INSTALL_S22}` + preuves légères.

- [x] Reviewer distinct en lecture seule sur diff V1.3.1→V1.4 ; corriger défauts critiques/importants par tests rouges→verts.
- [x] Tests packages + World L1 + sample complet, analyse, contrôles frontières/sécurité et lockfiles ; publier sorties avec SHA exact.
- [x] Compiler APK ARM64 ; contrôler ABI, manifeste fusionné, modèle EmbeddingGemma et signature/hash ; aucun succès annoncé pendant un run.
- [x] Rapport : commits canoniques GitHub, runs, artefacts, tests simulés/réels, limitations S22 et préservation d'installations.
- [x] Aucun merge stable ; livraison branche expérimentale seulement.


## Clôture du plan

Résultat logiciel validé au commit a569a2cb434d5d58ac26bc049294353c20655ca1.
Preuves : docs/living-memory/v1.4/REPORT.md et BUILD.json ; runs40859640417
et40859640335 réussis. Les coches indiquent la réalisation logicielle et ses
vérifications CI, sans transformer les essais matériels non exécutés en succès.
Signature stable préparée seulement ; clé externe d'origine nécessaire pour
une mise à jour compatible. Branche isolée conservée, aucun merge stable.
