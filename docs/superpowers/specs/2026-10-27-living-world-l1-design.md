# Architecture cible et spécification technique proposée

Statut : proposition L0 à valider, aucune implémentation. Référence : ../../../spec-reference.txt et ../../../01-audit.md. Le cahier des charges original prime sur cette spécification ; les valeurs ajoutées ici sont des paramètres d'essai proposés.

## Architecture et dépendances

| Module | Propriétaire de | Dépend de | Ne doit pas dépendre de |
|---|---|---|---|
| world_core, Dart pur | État autoritaire, ticks, validation, stocks, chemins, transactions logiques | world_contracts | Flutter, GPU, sqlite, modèle, réseau |
| agent_runtime, Dart pur | Perception, besoins, objectifs, propositions, équité | world_contracts ; ports mémoire/modèle | Widgets, SQL interne, outils téléphone |
| world_observer, Flutter | Caméra, sélection, fiches, contrôles, journal | Vues immuables ; commandes du core | Écritures directes dans le monde ou la mémoire |
| world_persistence, Dart/IO | Snapshots, manifeste, journal, reprise, outbox | world_contracts, world_core codec | Modèles ou reconstruction de souvenirs |
| living_memory, package à extraire en L2 | Sources mémorisables, index, souvenirs, versions, contradictions | Port embedding, stockage privé | Règles de faim, caméra, simulation |
| model_gateway, adaptateur L2 | Cycle de vie et budget commun génération/embedding | Ports ; services natifs existants | Actions autoritaires du monde |
| diagnostics | Mesures et preuves | Événements et compteurs bornés | Prompts/documents personnels dans les logs |

Direction : Observer → WorldCore.submit ; AgentRuntime → WorldCore.submit ; WorldCore → WorldEvent et Snapshot ; Persistence ← commit cohérent ; MemoryPort ← outbox d'événements perçus après commit ; ModelPort → ActionProposal → validation WorldCore. Une sortie IA ne peut pas appeler un mutateur d'état. La mémoire produit des références, jamais un nouvel état physique.

L1 utilise un appel de tick explicite, testable sans horloge réelle. La boucle Flutter traduit le temps écoulé en ticks avec rattrapage borné et expose requestedSpeed/effectiveSpeed. L'API du core reste utilisable dans un isolate ou une CLI Dart. Le passage effectif en worker sera mesuré : ne pas lancer un isolate par habitant. L6 ajoutera l'observateur distant et un seul propriétaire actif par worldId ; aucun serveur déployé en L1.

## Placement proposé sans nouveau dépôt

Après validation seulement : nouvelle branche work/living-world-l1-observable, à partir du SHA V1.2 audité, sans fusion ni changement des branches main/V1.1/V1.2. Les modules world sont ajoutés à la racine packages/ et apps/, sans changer samples/litert/flutter en L1.

packages/world_contracts : valeurs et contrats sérialisables, sans import Flutter ni Living Memory.
packages/world_core : simulation et règles.
packages/agent_runtime : décisions classiques, label « règles locales ».
packages/world_persistence : fichiers/transactions de sauvegarde.
apps/world_observer : application Flutter Android distincte com.tivini.livingworld.
tools/world_headless : CLI Dart de smoke test, sans réseau ; vérifie dès L1 la séparation du rendu.

L2 : extraire la source canonique de Living Memory en package réutilisable et faire dépendre ses deux applications de ce même package, dans un lot dédié soumis à tests de non-régression. Ne pas copier memory_store.dart dans world_core, ne pas importer les fichiers du sample par chemins relatifs et ne pas partager un fichier SQLite entre deux applications Android. Une seule implémentation de mémoire ; des bases distinctes pour les corpus monde et personnels sont une isolation, pas deux moteurs de mémoire. Les données personnelles existantes ne sont ni migrées ni copiées dans le monde implicitement.

## Contrats de monde, version 1

Toutes les structures ci-dessous sont des contrats proposés et non des API existantes. Encodage JSON UTF-8, enums par chaînes fermées, entiers bornés, aucune donnée NaN/Infinity. Identifiants opaques ASCII [a-zA-Z0-9_-], maximum 64 caractères ; worldId et agentId obligatoires. Liste inconnue de champs/types rejetée à l'entrée des commandes ; une version future de sauvegarde est refusée sans écrasement.

| Type | Champs fixés |
|---|---|
| WorldConfig | schemaVersion=1, rulesVersion=1, seed non nul uint32, width/height 1..256, populationMax 1..1000 |
| GridPos | x:int, y:int ; positions dans les bornes de la carte |
| WorldState | worldId, config, tick>=0, revision>=0, rngState:uint32, agents, resources, blockedCells, appliedCommandIds, pendingActions, schedulerCursor:int>=0, decisionSequence:int>=0, eventLog:List<WorldEvent> |
| AgentState | id, name, position, hunger 0..100, energy 0..100, inventoryFood>=0, currentAction?, goal, failureCount>=0, nextDecisionTick>=0, behaviorProfile=local_v1 |
| ResourceState | id, position, food>=0, reservationAgentId?, reservationUntilTick? |
| WorldEvent | schemaVersion=1, eventId, worldId, tick, revision, actorId?, kind, payload, commandId?, observedBy:List<agentId> |
| ActionProposal | schemaVersion=1, commandId, worldId, actorId, expectedRevision, issuedTick, expiresTick, kind, arguments |
| PendingAction | commandId, actorId, kind, arguments, startedTick, dueTick, reservedResourceId?, status ; tous les identifiants doivent résoudre une référence valide |
| ActionResult | commandId, status applied/rejected/pending, code, events:List<WorldEvent> |
| WorldSnapshot | state:WorldState ; collections immuables, copie défensive |
| WorldView | snapshot, selectedAgentId?, requestedSpeed, effectiveSpeed, mode rules/local_model |

Tool kind L1 : move, gather, consume, rest. Dialogue, création humaine et administration passent par des contrats séparés ; rien de narratif n'invente un effet. Réponses à une commande tardive : paused, expired, stale_revision, wrong_world, invalid_actor, invalid_arguments, unreachable, unavailable_resource, insufficient_inventory, actor_busy, duplicate. L'action rejetée ne change aucun stock ; duplicate ne réapplique pas l'effet. Le moteur garde une fenêtre persistée de déduplication de 1 024 commandId ; toute commande antérieure à cette fenêtre est rejetée par expiresTick/revision. Les IDs d'événements sont SHA-256 du JSON canonique [worldId,revision,index] (64 hex), sans timestamp réel obligatoire pour la logique.

## Règles L1 proposées, fixées pour rendre les tests exécutables

Profil de départ : carte 64×64, graine 1, 5 habitants, plafond initial 20, 4 ticks par seconde murale, vitesses 1×/2×/4×, rendu cible 30 FPS. Ce sont des valeurs d'essai, pas une capacité validée du S22. La grille autorise quatre voisins, dans l'ordre nord/est/sud/ouest ; recherche BFS bornée au nombre de cellules, sans diagonale. Génération PRNG xorshift32 documentée et versionnée ; état sauvegardé, valeur seed=0 refusée. Le scénario de recette fixe un obstacle, une réserve accessible et une destination inaccessible ; la génération ne doit pas promettre que tous les points aléatoires sont reliés.

À chaque période de 40 ticks : faim +1, énergie −1 pendant activité ; au repos énergie +4. Bornage 0..100 ; faim haute signifie besoin élevé. À énergie≤30 choisir repos en premier ; sinon faim≥60 choisir nourriture, sinon exploration bornée. Sans nourriture, échec explicite puis attente de 40 ticks ; aucun bouclage infini. Une collecte coûte 4 ticks et prend 1 unité ; consommation instantanée à un tick de décision, retire 1 unité et faim −40 ; repos dure au moins 40 ticks et peut être réévalué ensuite. Déplacement : une cellule par tick d'action ; un seul acte actif par agent. Aucun décès ni naissance dans L1.

La phase de décision traite les agents par rotation round-robin persistée ; au maximum une proposition par agent et par tour. Le profil behaviorProfile=local_v1 est conservé ; nextDecisionTick conserve les attentes après échec. Le journal eventLog fait partie de WorldState, est encodé/comparé par valeur et conserve observedBy. Il est borné selon la politique de sauvegarde ci-dessous, sans information secrète ajoutée dans les observations. Le core seul valide la commande, réserve une unité avant collecte et expire la réservation si l'agent abandonne. Deux agents ne peuvent pas prendre la même dernière unité. L1 n'ajoute pas un simulateur de collisions physiques entre habitants ; le partage d'une cellule est autorisé, les obstacles de terrain sont bloquants.

Réduire populationMax sous l'effectif bloque les ajouts sans supprimer personne. La limite doit aussi être vérifiée à l'import et à la création. La sauvegarde/reprise autorise cet état après baisse de plafond. À l'import, si l'effectif dépasse le plafond du fichier, proposer un relèvement explicite via populationMaxOverride, borné 1..1000 et au moins égal à l'effectif ; sans choix explicite, refuser sans rien modifier. L'export reste fidèle au plafond abaissé ; son réimport est possible avec ce relèvement, jamais avec une suppression d'habitants. Retour Android depuis PC hors limites : refus sans altérer le monde existant.

## Horloge et pause

Le chemin complet hôte/CLI passe par SimulationRunner.advance(int ticks) : pour chaque tick demandé, si le core est en pause, ne rien faire ; sinon exécuter LocalAgentRunner.decideRound(), puis WorldCore.step(1). Ne jamais décider une seule fois par frame ou par lot de ticks. Le runner reconsulte snapshot/revision avant chaque proposition, passe les agents occupés ou dont nextDecisionTick est futur, puis appelle WorldCore.finishDecisionRound() une fois par tour. Cette dernière méthode incrémente schedulerCursor modulo le nombre d’agents et la révision. WorldCore.issueCommandId(String actorId) incrémente decisionSequence et la révision, puis renvoie SHA-256 du JSON canonique [worldId,actorId,tick,decisionSequence] (64 hex) ; la proposition prend expectedRevision après cette émission. decisionSequence et schedulerCursor sont persistés ; aucune génération d’ID ne dépend du temps réel. La méthode de progression complète reste identique en UI et en CLI.

WorldCore.step(ticks) reçoit un entier 0..1000, rejette les autres valeurs ; paused ⇒ ni tick ni besoins ni tâches ne progressent. Après reprise, aucune compensation du temps en arrière-plan. Loop côté hôte : maximum 8 ticks par rafraîchissement ; le surplus reporte du temps, ne saute pas d'actions. effectiveSpeed = ticks exécutés / durée mesurée / cadence nominale, sur fenêtre proposée de 2 secondes. Pause/arrêt invalide les propositions en attente ; toute future réponse IA devra être revalidée à la reprise, pas appliquée automatiquement.

## Caméra et interface

InteractiveViewer/CustomPainter envisagés, rendu des seules cellules visibles, fond statique réutilisé. Pan et zoom n'altèrent aucune coordonnée du monde. Zoom proposé 0,5..4, boutons ×1,25 et ÷1,25 ; les quatre bords restent atteignables. Seuil de glissement proposé 8 pixels logiques avant exclusion du tap. Transformation inverse pour sélectionner ; toucher intentionnel ouvre la fiche. Suivi caméra désactivé dès un pan humain. Recentrage et recherche par habitant présents ; mini-carte avancée reportée L3.

UI française, échelle du texte système, commandes sémantiques et icônes avec libellé ; besoins affichés aussi par nombres. Fiche L1 : besoins, objectif, action, échecs ; relations/souvenirs/conversations affichés comme indisponibles dans cette version plutôt que fabriqués. Journal borné et paginé (500 événements conservés dans la vue, archives selon politique ci-dessous). Aucune génération fictive montrée comme IA réelle.

## Sauvegarde L1 et propriété des données

Snapshots versionnés du monde et journal borné des événements physiques uniquement. Pas de vecteurs, pas de RAG, pas de table de souvenirs dans le stockage monde. La projection d'un souvenir reste propriété exclusive de Living Memory. Les événements physiques sont des preuves source ; conserver eventId pour relier la mémoire et l'état.

Stratégie L1 : générations de fichiers immutable checkpoint-N.json + manifeste.json, SHA-256 du corps canonique, écriture temporaire puis flush et renommage dans le même dossier. Deux générations valides conservées ; ne pas supprimer la précédente avant validation de la nouvelle. Charger la génération validée la plus récente ; si corruption/interruption, restaurer la précédente et informer. Après crash avant validation de manifeste, les fichiers orphelins sont ignorés. Le journal nécessaire à la reprise est contenu dans la génération ; pas de journal append externe dont l'offset pourrait diverger du snapshot. Borne proposée : 10 000 événements par monde, archives/export explicites avant rétention. En L2, les événements non acquittés par la mémoire sont épinglés et ne sont jamais purgés silencieusement.

Snapshot inclut journal eventLog avec observedBy, RNG, round-robin, decisionSequence, commandes récentes et actions/réservations en cours. Chargement valide toutes les références, les bornes et l'unicité ; aucun code objet arbitraire désérialisé. Import JSON au maximum 16 MiB avant parse, 65 536 cellules, 1 000 agents, 10 000 événements ; refus d'une version future, d'identifiants dupliqués, références manquantes ou entiers excessifs. Les deux générations sont une récupération opérationnelle, pas une sauvegarde externe ; export manuel disponible pour L1. Pas de copie d'une base SQLite ouverte.

Sauvegarde automatique proposée tous les 200 ticks et au passage inactive/paused, avec sérialisation des écritures ; sur arrêt forcé avant callback, dernière génération validée. En cas de disque plein, garder l'ancien état et afficher l'erreur. L'utilisateur peut relancer la sauvegarde. Pas de rattrapage hors ligne, service permanent ou synchronisation distante en L1.

## Contrat Living World ↔ Living Memory proposé pour L2

MemoryPort ne transporte que des événements perçus par l'agent ; pas l'état secret global. Méthodes asynchrones :

```dart
Future<MemoryAck> ingest(PerceivedEvent event);
Future<List<MemoryReference>> recall(RecallQuery query);
Future<void> delete(ScopedMemoryId id);
Future<MemoryHealth> health();
```

PerceivedEvent : schemaVersion=1, worldId, agentId, eventId, tick, writtenAtUtc, kind observation/declaration/hypothesis/inference, text, sourceRevision, parentEventIds. MemoryAck : eventId, agentId, status accepted/already_present/rejected, sourceId?, reason?. RecallQuery : worldId, agentId, text, topK 1..20, contextBudgetBytes ; MemoryReference : memoryId, sourceEventIds, tick, kind, status, text, score, version. ScopedMemoryId contient les trois identifiants monde/agent/souvenir. MemoryHealth : ready/unavailable/degraded, reason. Types définis par T1 du plan ; aucune fausse implémentation fonctionnelle dans L1.

Les agents Living Memory ont une clé déterministe SHA-256(worldId + séparateur NUL + agentId), 64 hex, conforme à la limite du store. MemoryScope(userId=local, projectId=living-world, worldId, agentId=clé). Le séparateur est dans la préimage seulement, jamais dans l'ID ni la portée. Cette correspondance doit être testée ; les identifiants externes restent dans l'événement source. Toute recherche applique les deux portées avant ranking, y compris le futur lexical.

Flux transactionnel inter-composants L2 : commit état+événement+outbox dans la sauvegarde monde ; ensuite ingestion ; déduplication sur (worldId, agentId, eventId) côté mémoire ; ack puis marquage outbox acquittée. Si crash entre ingestion et ack : réessai, pas deuxième souvenir. Aucune transaction distribuée supposée. Les textes sources sont une projection citée de l'événement ; le monde ne conserve pas une deuxième base de souvenirs. La suppression d'une mémoire retire ses index/résumés selon politique, sans supprimer arbitrairement le fait historique du monde. Une rétention documentaire doit expliquer cette différence à l'utilisateur.

Déclarations restent déclarations ; événements vérifiés par le core peuvent recevoir un statut engine_observed distinct de user_confirmed. Ne pas confirmer silencieusement des extractions génératives. Ce statut, le fallback lexical et l'outbox sont des travaux L2, pas des capacités actuelles. Export L2 réunit un snapshot monde et un export Living Memory cohérents à un même point de coupure, avec manifests de modèles séparés.

## Contrat modèles futur

ModelPort : capabilities(), generate(DecisionRequest), cancel(requestId), release(). DecisionRequest porte requestId, worldId, agentId, observedRevision, deadlineTick, prompt structuré et contextBudget. DecisionReply porte requestId, modelId réel, hash, action structurée et usage mesuré. Adaptation vers MultiModelEngine.run sans le renommer ModelRuntime. Sérialisation commune génération/embedding et pas de fallback si libération native incertaine. E4B non activé par défaut. Le L1 ne contient ni ce runtime ni un faux modèle servant de preuve IA.

## Conditions d'acceptation

L1 : R01–05, R13 création/import, R16–18 pour données monde, partie pause de R06, CLI sans rendu et tests négatifs de commandes/import. Le reste est tracé vers les lots appropriés. Les propositions d'architecture et le plan nécessitent validation explicite avant installation de dépendances produit, création de branche ou programmation. L0 ne déclare pas que les fonctions L1 existent déjà.
