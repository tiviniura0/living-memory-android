# Living World AI L1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans pour une exécution native tâche par tâche ; ou superpowers:subagent-driven-development si Tivini choisit explicitement cette méthode. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Livrer un monde 2D observable sur Android, avec règles locales, navigation, besoins, stocks et sauvegarde restaurable.

**Architecture:** Core Dart pur, contrats versionnés, agent classique indépendant, persistence séparée, observateur Flutter. Living Memory n'est pas recopié ni modifié dans L1 ; son intégration réelle est un lot L2 conditionné par les preuves matérielles.

**Tech Stack:** Dart et Flutter, version de départ proposée Flutter 3.47.3 / Dart compatible SDK ^3.13.3 telle que la CI auditée ; dépendances verrouillées, aucun upgrade automatique. package:test pour Dart pur, flutter_test/integration_test pour l'app ; versions résolues puis verrouillées au bootstrap après validation.

**Spec:** ../specs/2026-10-27-living-world-l1-design.md ; référence complète ../../../spec-reference.txt ; audit ../../../01-audit.md. Tous les paramètres ci-dessous sont proposés pour validation, pas des mesures matérielles.

## Global Constraints

- « Préserver le travail et les données existants ; ne pas recréer Living Memory. »
- « Séparer la simulation, la mémoire, les modèles et l’affichage pour pouvoir les améliorer indépendamment. »
- « Privilégier le fonctionnement local, les outils gratuits et les preuves concrètes. Aucune dépense automatique. »
- « Accepter des trajectoires inattendues, avec des effets soumis aux règles du monde. »
- Cible : Samsung Galaxy S22 Ultra, 12 Go RAM. Aucune capacité déduite de la seule RAM nominale.
- Aucune implémentation avant validation du présent plan et de la spécification ; aucune fusion vers main ou branches V1.1/V1.2 autorisée.
- Départ Git exact : 376ccf33353ec101b1c424b6121eb69ecfc55f62. Branche future work/living-world-l1-observable ; vérifier qu'elle n'existe pas avant de la créer. Si elle existe, l'examiner et poursuivre sans reset.
- Utiliser using-git-worktrees avant exécution ; worktree isolé, état des branches relevé, jamais git clean/reset sur le travail utilisateur.
- Pas de téléchargement de poids IA, pas de service, modèle factice ou appel cloud dans L1. Afficher le mode réel « règles locales ».
- Tous les chemins du plan sont relatifs à la racine du dépôt. Les tests proposés n'ont pas été écrits ou exécutés pendant L0.

## Review Focus

1. Import malformé ou version future : refuser sans écraser l'ancien monde (T1/T6).
2. Interruption après fichier temporaire, avant manifeste, ou disque plein : récupérer une génération valide (T6/T8).
3. Commande retardée, répétée ou adressée à un objet disparu : aucun effet indu ou double consommation (T3/T4).
4. Caméra déplacée/zoomée et grands textes : sélection fiable, quatre bords accessibles et contrôles lisibles (T7).
5. Plafond abaissé sous l'effectif ou retour d'arrière-plan : conserver habitants et temps sauvegardé, sans rattrapage caché (T2/T8).

## Structure prévue

| Répertoire | Responsabilité | Dépendances permises |
|---|---|---|
| packages/world_contracts | DTO, JSON, MemoryPort, validation de frontières | Dart core ; aucune plateforme |
| packages/world_core | Monde, horloge, commandes, chemins, stocks | world_contracts |
| packages/agent_runtime | Politique locale, perception, round-robin | world_contracts, API publique world_core |
| packages/world_persistence | Checkpoints, import/export, intégrité | Dart IO, crypto verrouillé, contracts/core |
| apps/world_observer | Flutter UI et hôte Android | Packages monde ; aucun sample mémoire |
| tools/world_headless | CLI, smoke et comparaison de snapshots | Packages monde sans Flutter |
| fixtures/world | Scénarios JSON partagés de recette | Données, aucun code |
| docs/living-world | Protocole, limites, tests et notices | Documentation |

Chaque package possède pubspec.yaml et lockfile s'il est résolu par la CI ; aucun workspace racine ne modifie la résolution du sample existant. Les chemins exacts de fichiers figurent dans les tâches. Aucun fichier samples/litert/flutter n'est modifié par L1.

## Règle TDD commune

Chaque tâche suit les cinq étapes ci-dessous et constitue un commit révisable. Pour un nouveau package, créer seulement le manifeste et les signatures/stubs nécessaires à la compilation des tests ; le rouge doit ensuite être une assertion sur le comportement absent, pas un import cassé. Ne pas écrire la logique produit avant d'avoir vu ce rouge. Après vert : refactoriser si utile, relancer la suite du package et les consommateurs affectés. Conserver la preuve rouge/verte avec SHA dans docs/living-world/test-report.md ou artefacts CI. Les extraits de test du plan sont des attentes à écrire, pas du code déjà livré.

### Task 1 — Contrats, codec et frontières

**Files:** Create packages/world_contracts/pubspec.yaml, lib/world_contracts.dart, lib/src/world_types.dart, lib/src/world_codec.dart, lib/src/memory_port.dart ; Test test/world_codec_test.dart, test/memory_scope_test.dart ; Create fixtures/world/l1_world.json, fixtures/world/schema1.json.

**Interfaces:** Produit les types du tableau « Contrats de monde » de la spec, immuables avec égalité par valeur ; WorldCodec.encode(WorldState)->String et WorldCodec.decode(String)->WorldState. Produit MemoryPort et ses six DTO décrits dans la spec ; aucune implémentation. Produit String memoryAgentKey(String worldId,String agentId), SHA-256 de la préimage spécifiée, en séparant l'algorithme dans lib/src/memory_agent_key.dart (dépendance crypto explicitement ajoutée) ou en injectant ce hachage en L2 : pour L1 retenir ce fichier et la dépendance crypto verrouillée, sans Flutter.

Fixture l1_world : worldId=world1, seed=1, grille 64×64, tick/revision=0, populationMax=20 ; cinq agents a1..a5 aux cellules (1,1),(1,2),(1,3),(1,4),(1,5), hunger=60, energy=80, inventaire=0 ; une ressource food1 en (2,1), food=1 ; cellule (3,1) bloquée et cellule (5,5) encerclée par quatre obstacles ; pendingActions et eventLog vides. RNG=1 ; schedulerCursor=0 ; decisionSequence=0 ; behaviorProfile=local_v1 ; nextDecisionTick=0 pour chaque agent. Paramètres de la fixture entièrement sérialisés, pas complétés depuis l'heure courante.

- [ ] **Step 1: Write failing tests** roundtrip_schema1_preserves_state ; rejects_future_version ; rejects_unknown_command_kind ; rejects_duplicate_agents ; memory_key_separates_worlds.

```dart
expect(WorldCodec.decode(WorldCodec.encode(state)), state);
expect(() => WorldCodec.decode(futureVersionJson), throwsFormatException);
expect(memoryAgentKey('w1', 'a'), isNot(memoryAgentKey('w2', 'a')));
expect(memoryAgentKey('w1', 'a').length, 64);
```

- [ ] **Step 2: Run RED** cd packages/world_contracts && dart test -r expanded ; échec attendu de round-trip/validation sur stubs, pas absence de package.
- [ ] **Step 3: Implement** DTO et codec stricts, limites de la spec ; la préimage du hash n'est jamais exposée dans la portée.
- [ ] **Step 4: Run GREEN** dart analyze && dart test -r expanded ; zéro échec. Vérifier que les imports transitifs n'incluent Flutter ni IO.
- [ ] **Step 5: Commit** git add packages/world_contracts fixtures/world ; git commit -m "feat(world): define versioned contracts and portable fixtures".

### Task 2 — État déterministe, horloge et plafond

**Depends on:** T1.
**Files:** Create packages/world_core/pubspec.yaml, lib/world_core.dart, lib/src/world_core.dart, lib/src/world_factory.dart, lib/src/world_rng.dart ; Test test/world_clock_test.dart, test/world_factory_test.dart, test/population_test.dart, test/support.dart.

**Interfaces:** WorldFactory.create(String worldId,WorldConfig config,int population)->WorldState ; WorldCore(WorldState initial), WorldSnapshot snapshot(), List<WorldEvent> step(int ticks), void setPaused(bool value), ActionResult setPopulationMax(int value), ActionResult addAgent(AgentState agent), void finishDecisionRound(), String issueCommandId(String actorId). finishDecisionRound avance le cursor et la révision ; issueCommandId avance decisionSequence/révision. Les champs du codec sont ceux de la spec, dont eventLog/cursor/séquence. Test helper WorldCore fixtureCore() charge la fixture T1 via codec ; reste dans test/support.dart. RNG nextUint32() et state exportable, xorshift32 version 1.

- [ ] **Step 1: Write failing tests** same_seed_same_map ; restored_rng_same_sequence ; paused_step_preserves_state ; lower_cap_keeps_agents ; add_over_cap_rejected ; invalid_tick_count_rejected.

```dart
core.setPaused(true);
final before = core.snapshot();
core.step(40);
expect(core.snapshot(), before);
expect(core.setPopulationMax(2).status, ActionStatus.applied);
expect(core.snapshot().state.agents.length, 5);
expect(core.addAgent(extraAgent).status, ActionStatus.rejected);
```

- [ ] **Step 2: Run RED** cd packages/world_core && dart test -r expanded ; assertions pause/plafond échouent sur les stubs.
- [ ] **Step 3: Implement** état autoritaire, PRNG sérialisé, ticks sans rendu ni temps réel, création/import/ajout bornés ; aucune naissance L1.
- [ ] **Step 4: Run GREEN** dart analyze && dart test -r expanded ; vérifier seed=0, dimensions extrêmes et invariants après 10 000 ticks (sans mesurer une performance S22).
- [ ] **Step 5: Commit** git add packages/world_core ; git commit -m "feat(world): add deterministic clock and population policy".

### Task 3 — Commandes, chemins et déplacements

**Depends on:** T1/T2.
**Files:** Create world_core/lib/src/command_validator.dart, lib/src/grid_pathfinder.dart, lib/src/movement.dart (préfixe packages/ pour tous) ; Modify packages/world_core/lib/src/world_core.dart ; Test test/pathfinder_test.dart, test/command_test.dart dans ce package.

**Interfaces:** GridPathfinder.findPath(WorldState state,GridPos start,GridPos goal)->List<GridPos>? ; WorldCore.submit(ActionProposal command)->ActionResult. Le chemin exclut start et inclut goal ; start==goal renvoie liste vide ; unreachable renvoie null. Command IDs récents et réservations dans snapshot ; revision avance lors d'une mutation, y compris step réussi ; ordre d'une commande→événements déterministe.

- [ ] **Step 1: Write failing tests** route_avoids_obstacle ; unreachable_returns_null ; move_advances_one_cell_per_tick ; rejects_stale_revision ; rejects_paused ; rejects_expired ; replay_has_no_second_effect ; missing_actor_rejected.

```dart
expect(path.contains(const GridPos(3, 1)), isFalse);
expect(pathfinder.findPath(state, start, const GridPos(5, 5)), isNull);
final first = core.submit(command);
final afterFirst = core.snapshot();
expect(core.submit(command).code, 'duplicate');
expect(core.snapshot(), afterFirst);
expect(first.status, isNot(ActionStatus.rejected));
```

- [ ] **Step 2: Run RED** cd packages/world_core && dart test test/pathfinder_test.dart test/command_test.dart -r expanded ; échouer sur chemin/validation, pas construction de fixtures.
- [ ] **Step 3: Implement** BFS N/E/S/O, max cellules visitables ; mutation uniquement par core ; expiration tick et revalidation à chaque achèvement d'action. Une commande périmée n'est jamais rejouée à la reprise.
- [ ] **Step 4: Run GREEN** dart analyze && dart test -r expanded ; positions toujours dans les limites, obstacles jamais traversés.
- [ ] **Step 5: Commit** git add packages/world_core ; git commit -m "feat(world): validate commands and bounded grid movement".

### Task 4 — Besoins, collecte, consommation et repos

**Depends on:** T3.
**Files:** Create packages/world_core/lib/src/needs_rules.dart, resource_actions.dart ; Modify world_core.dart et world_types.dart seulement si ajout strictement requis au DTO validé ; Test packages/world_core/test/needs_test.dart, resource_transaction_test.dart.

**Interfaces:** NeedsRules.advance(AgentState agent,int fromTick,int toTick,bool resting)->AgentState ; core.submit traite gather(resourceId), consume, rest via arguments validés ; événements resource_reserved, collected, consumed, rested ou action_failed, avec actorId/source et stocks avant/après.

- [ ] **Step 1: Write failing tests** metabolism_after_40_ticks ; clamp_needs ; two_agents_last_food_once ; consume_without_food_rejected ; busy_actor_rejected ; abandoned_reservation_expires ; deleted_resource_late_action_rejected.

```dart
expect(after40.hunger, before.hunger + 1);
expect(after40.energy, before.energy - 1);
expect(finalResource.food, 0);
expect(agents.fold<int>(0, (sum, a) => sum + a.inventoryFood), 1);
expect(negativeStockEvents, isEmpty);
```

Dernière ressource : soumettre deux commandes successives avec la révision courante à chaque appel afin que le second refus vérifie la réservation, pas seulement stale_revision. Consommation −40 de faim, repos +4 par 40 ticks, bornes 0/100 ; collecte finit après 4 ticks.

- [ ] **Step 2: Run RED** cd packages/world_core && dart test test/needs_test.dart test/resource_transaction_test.dart -r expanded.
- [ ] **Step 3: Implement** réservations et commit des effets atomiques dans l'état core, sans await entre vérification et application ; tout échec laisse stocks/inventaires inchangés.
- [ ] **Step 4: Run GREEN** dart analyze && dart test -r expanded ; scénario 10 000 ticks et conservation nourriture collectée/consommée.
- [ ] **Step 5: Commit** git add packages/world_core ; git commit -m "feat(world): enforce needs and transactional resources".

### Task 5 — Habitants autonomes par règles et perception

**Depends on:** T4.
**Files:** Create packages/agent_runtime/pubspec.yaml, lib/agent_runtime.dart, lib/src/local_policy.dart, lib/src/perception.dart, lib/src/round_robin.dart, lib/src/simulation_runner.dart ; Test test/local_policy_test.dart, test/fairness_test.dart, test/perception_test.dart.

**Interfaces:** Perception.forAgent(WorldSnapshot snapshot,String agentId)->AgentObservation (agent propre, cellules/agents/ressources à distance Manhattan≤6, événements dont observedBy contient l'agent). LocalPolicy.propose(AgentObservation observation)->ActionProposal? ; LocalAgentRunner(WorldCore core), List<ActionResult> decideRound() ; SimulationRunner(WorldCore core,LocalAgentRunner agents), List<WorldEvent> advance(int ticks). advance exécute décisions puis step(1) pour chaque tick, jamais une seule décision par lot ; aucune progression du cursor si paused. Cursor conservé via finishDecisionRound ; IDs émis par issueCommandId, puis snapshot/revision relus pour construire la proposition, sans DateTime.now. Le runner consomme l'API publique du core, aucun accès aux maps mutables.

- [ ] **Step 1: Write failing tests** energy_urgent_before_hunger ; hungry_seeks_food ; unreachable_waits_40_ticks ; no_secret_outside_perception ; all_agents_get_turns ; no_cam_bias ; batched_ticks_match_single_ticks ; restored_sequence_preserves_ids.

```dart
expect(policy.propose(tiredAndHungry).kind, ActionKind.rest);
expect(observation.resources.any((r) => r.id == hiddenId), isFalse);
expect(turns.keys.toSet(), allAgentIds);
expect(turns.values.reduce(max) - turns.values.reduce(min), lessThanOrEqualTo(1));
```

Équité vérifiée sur 100 tours, caméra absente des entrées ; chaque échec répété est borné, l'agent attend/replanifie, aucun accès à la mémoire personnelle.

- [ ] **Step 2: Run RED** cd packages/agent_runtime && dart test -r expanded ; échecs sur priorité, perception ou équité.
- [ ] **Step 3: Implement** règles chiffrées de la spec, exploration déterministe parmi cellules perçues, round-robin ; modes et motifs explicitement journalisés. Pas de prétendue conversation entre habitants dans L1.
- [ ] **Step 4: Run GREEN** dart analyze && dart test -r expanded puis suite world_core ; au moins une collecte, consommation et phase de repos observables dans un scénario de recette adapté avec nourriture suffisante.
- [ ] **Step 5: Commit** git add packages/agent_runtime ; git commit -m "feat(world): add bounded local agent decisions".

### Task 6 — Sauvegarde, reprise et import/export

**Depends on:** T1–T5.
**Files:** Create packages/world_persistence/pubspec.yaml, lib/world_persistence.dart, lib/src/checkpoint_store.dart, lib/src/checkpoint_codec.dart, lib/src/file_ops.dart ; Test test/checkpoint_test.dart, crash_recovery_test.dart, import_validation_test.dart ; Create fixtures/world/corrupt.json, schema_future.json.

**Interfaces:** CheckpointStore(Directory directory,{FileOps? files}), Future<void> save(WorldSnapshot snapshot), Future<LoadResult> load(), Future<String> exportJson(), Future<LoadResult> importJson(String json,{int? populationMaxOverride}). load accepte un effectif au-dessus du plafond après baisse ; import exige dans ce cas un relèvement explicite du plafond, jamais de suppression. LoadResult contient snapshot?, recovered:bool, warnings:List<String>. FileOps abstrait writeFlushed/rename/read/list pour injection de fautes d'IO ; production utilise Dart IO, tests utilisent aussi un vrai dossier temporaire. CheckpointCodec valide manifeste, SHA-256 et limites avant activation.

- [ ] **Step 1: Write failing tests** roundtrip_mid_action ; interrupted_before_manifest_uses_previous ; corrupt_latest_falls_back ; disk_full_preserves_previous ; future_import_preserves_world ; duplicate_id_import_rejected ; oversized_import_rejected ; import_population_over_cap_rejected ; lower_cap_save_restore_keeps_all_agents ; lower_cap_export_import_roundtrip_with_explicit_override ; event_log_and_observedBy_survive_restore.

```dart
await store.save(before);
await expectLater(store.save(after), throwsA(isA<FileSystemException>()));
expect((await healthyStore.load()).snapshot, before);
expect((await store.load()).snapshot!.state.rngState, before.state.rngState);
```

Tester séparément crash après fichier temporaire, après renommage checkpoint et avant/après manifeste. actions, réservations, cursor, événements et commandes récentes conservés ; import malveillant de chemin n'accède à aucun fichier hors dossier.

- [ ] **Step 2: Run RED** cd packages/world_persistence && dart test -r expanded ; tests contre fichiers temporaires réels, fautes injectées seulement aux frontières IO.
- [ ] **Step 3: Implement** deux générations, vérification avant activation, aucun écrasement de sauvegarde valide sur erreur ; bornes et rétention de la spec. Export sans poids IA et sans données personnelles.
- [ ] **Step 4: Run GREEN** dart analyze && dart test -r expanded puis suites core/agents ; comparer état intégral après fermeture/réouverture, pas seulement tick.
- [ ] **Step 5: Commit** git add packages/world_persistence fixtures/world ; git commit -m "feat(world): persist recoverable versioned checkpoints".

### Task 7 — Observateur Flutter : caméra et fiche

**Depends on:** T1–T5 ; T6 requis pour reprise UI mais tests caméra indépendants.
**Files:** Create apps/world_observer/pubspec.yaml, lib/main.dart, lib/world_app.dart, lib/world_controller.dart, lib/map/world_painter.dart, lib/map/world_viewport.dart, lib/map/camera_controller.dart, lib/panels/agent_panel.dart, lib/panels/event_journal.dart ; Test test/camera_test.dart, test/selection_test.dart, test/accessibility_test.dart ; Android généré uniquement dans cette app après validation.

**Interfaces:** WorldController(WorldCore core,LocalAgentRunner runner,CheckpointStore store), ValueListenable<WorldView> view, void selectAgent(String?), setPaused(bool), setSpeed(int), setPopulationMax(int) ; Future<void> save(), Future<void> restore(). CameraController : toWorld(Offset screen)->GridPos?, pan(Offset delta), zoomAt(Offset focal,double factor), centerOn(GridPos), follow(String?), stopFollowing(). L'UI importe Flutter ; le core ne l'importe jamais.

- [ ] **Step 1: Write failing widget tests** reach_four_corners ; pinch_and_buttons_same_bounds ; drag_does_not_select ; tap_after_zoom_selects_expected ; pan_stops_follow ; large_text_french_controls.

```dart
expect(worldAfterGesture, worldBeforeGesture);
expect(controller.view.value.selectedAgentId, isNull); // après glissement >8 px
expect(camera.zoom, inInclusiveRange(0.5, 4.0));
expect(find.text('Règles locales'), findsOneWidget);
```

Tester portrait/paysage et textScaler 2.0 ; les contrôles restent utilisables sans couleur seule. Fiche besoins/action/objectif ; pas de faux souvenir, pas de fil de dialogue inventé.

- [ ] **Step 2: Run RED** cd apps/world_observer && flutter test test/camera_test.dart test/selection_test.dart test/accessibility_test.dart --reporter expanded.
- [ ] **Step 3: Implement** viewport indépendant et rendu culling, seuil glissement 8 pixels logiques, contrôles sémantiques français et journal paginé ; app ID com.tivini.livingworld. Pas de permissions caméra/micro/intents ni modèle embarqué.
- [ ] **Step 4: Run GREEN** flutter analyze && flutter test --reporter expanded ; interactions sur 64×64 et vérification de l'état avant/après gestes.
- [ ] **Step 5: Commit** git add apps/world_observer ; git commit -m "feat(world): add accessible 2D observer and camera".

### Task 8 — Boucle hôte, lifecycle et erreurs de stockage

**Depends on:** T6/T7.
**Files:** Create apps/world_observer/lib/runtime/world_loop.dart, lib/runtime/world_lifecycle.dart, test/world_loop_test.dart, test/lifecycle_test.dart, integration_test/resume_world_test.dart ; Modify lib/world_controller.dart.

**Interfaces:** WorldLoop.advance(Duration elapsed)->int (ticks réellement exécutés via SimulationRunner.advance), setSpeed(int) ∈{1,2,4}, setPaused(bool) ; WorldLifecycle.onState(AppLifecycleState)->Future<void> ; controller publie effectiveSpeed calculée sur fenêtre de 2 s et le statut de sauvegarde. L'entrée de lifecycle n'attend pas une génération IA inexistante dans L1.

- [ ] **Step 1: Write failing tests** max_8_ticks_per_frame ; pause_zero_tick ; reports_slow_actual_speed ; background_save_and_pause ; resume_no_walltime_catchup ; disk_full_keeps_ui_usable.

```dart
expect(loop.advance(const Duration(seconds: 20)), lessThanOrEqualTo(8));
expect(afterResume.state.tick, saved.state.tick);
expect(afterResume.state.agents, saved.state.agents);
expect(find.textContaining('Sauvegarde impossible'), findsOneWidget);
```

Le test du retour utilise horloge injectée ; le test d'arrêt forcé matériel vérifie la dernière génération validée, pas un callback Android garanti. Autosave tous les 200 ticks, écritures sérialisées ; erreurs visibles et réessai explicite.

- [ ] **Step 2: Run RED** cd apps/world_observer && flutter test test/world_loop_test.dart test/lifecycle_test.dart --reporter expanded.
- [ ] **Step 3: Implement** loop bornée, pause de fond, sauvegarde avant suspension si possible, restauration sans temps imaginé. Aucun foreground service ou permission d'arrière-plan.
- [ ] **Step 4: Run GREEN** flutter analyze && flutter test --reporter expanded ; sur S22 ensuite flutter test integration_test/resume_world_test.dart -d DEVICE_ID, ou recette depuis APK si pas de commande adb disponible. Ce test matériel ne peut être marqué réussi sans appareil.
- [ ] **Step 5: Commit** git add apps/world_observer ; git commit -m "feat(world): handle Android pause and recoverable lifecycle".

### Task 9 — CLI sans rendu et diagnostic reproductible

**Depends on:** T1–T6 ; UI non requise.
**Files:** Create tools/world_headless/pubspec.yaml, bin/world_headless.dart, lib/scenario_runner.dart, test/scenario_test.dart ; Create docs/living-world/BENCHMARK.md ; ajouter apps/world_observer/lib/diagnostics/world_metrics.dart, test/world_metrics_test.dart pour les métriques UI seulement.

**Interfaces:** ScenarioRunner.run(WorldState initial,int ticks)->WorldSnapshot utilisant SimulationRunner.advance pour le chemin complet ; CLI --fixture PATH --ticks INT --out PATH, code 0 sur succès, 2 sur configuration invalide. JSON résultat : SHA256 état canonique, tick, invariants, version règles ; aucune donnée aléatoire/temps réel dans le hash. Metrics expose temps de tick/frame, nombre d'agents/actions, taille sauvegarde ; buffers bornés et export JSON sans documents personnels.

- [ ] **Step 1: Write failing tests** headless_matches_step_by_step ; save_resume_same_hash ; invalid_input_exit_2 ; ui_and_headless_same_state ; metrics_buffer_bounded.

```dart
expect(headlessHash, singleTickSimulationHash);
expect(resumedHash, uninterruptedHash);
expect(batch100Hash, singleTick100Hash);
expect(result.exitCode, 2); // arguments invalides
expect(metrics.sampleCount, lessThanOrEqualTo(1000));
```

- [ ] **Step 2: Run RED** cd tools/world_headless && dart test -r expanded ; puis flutter test test/world_metrics_test.dart dans l'app.
- [ ] **Step 3: Implement** CLI et métriques sans Flutter dans le chemin headless, aucune simulation de résultat benchmark S22 ; documenter 5/10/20 habitants, 30 min et sources brutes.
- [ ] **Step 4: Run GREEN** dart analyze && dart test ; dart run bin/world_headless.dart --fixture ../../fixtures/world/l1_world.json --ticks 10000 --out run.json ; hash stable sur deux exécutions et après reprise.
- [ ] **Step 5: Commit** git add tools/world_headless docs/living-world/BENCHMARK.md apps/world_observer/lib/diagnostics apps/world_observer/test/world_metrics_test.dart ; git commit -m "test(world): prove headless operation and expose diagnostics".

### Task 10 — CI, APK et recette L1

**Depends on:** T1–T9.
**Files:** Create .github/workflows/world-l1.yml, docs/living-world/test-report.md, INSTALL_S22.md, LICENSES.md, DELIVERY.md ; Test apps/world_observer/integration_test/l1_village_test.dart ; scripts/check_world_boundaries.py et tests/test_world_boundaries.py vérifient imports interdits et absence de dépendance du core à Flutter/IO/modèles. Ces chemins restent nouveaux ; workflow mémoire inchangé.

**Interfaces:** CI tourne uniquement sur branche world/PR, permissions contents:read, pas de secrets modèles. Actions épinglées à SHA audités, Flutter épinglé, lockfiles imposés. Artefact APK+evidence étiqueté avec github.sha, hash, applicationId, ABI/signature, statut hardware_tested=false par défaut ; la réussite matérielle exige un rapport séparé signé par la preuve, jamais une valeur automatique true.

- [ ] **Step 1: Write failing tests** l1_complete_loop_restores ; boundary_check_detects_flutter_in_core ; boundary_check_accepts_dart_core ; no_personal_permissions_in_world_manifest ; app_id_differs_from_memory. Faire échouer le contrôle de frontières sur une fixture temporaire, sans ajouter d'import interdit dans le produit.
- [ ] **Step 2: Run RED** python3 -m unittest discover -s tests -p test_world_boundaries.py -v ; puis tests integration Flutter sur cible disponible. Conserver tout statut non exécuté explicitement.
- [ ] **Step 3: Implement** workflow : contrats → core → agents → persistence → headless → Flutter analyse/tests → build apk --release --target-platform android-arm64 → apksigner/aapt → preuves → upload. Signature dédiée durable nécessaire pour distribuer des mises à jour ; sans clé durable, APK expérimental signalé, ne pas désinstaller l'app existante.
- [ ] **Step 4: Run GREEN** toutes les suites complètes des six packages/apps et contrôle de frontières ; vérifier le run CI au SHA de tête et son artefact. Sur S22 : R01–05, R13 sans naissance, R16–18, pause R06, mode avion L1 et 30 min à 5 habitants ; puis 10/20 si stable. Joindre logs, mesures et limites. Pas de prétendu R19/L2 réussi.
- [ ] **Step 5: Commit** git add .github/workflows/world-l1.yml docs/living-world apps/world_observer/integration_test scripts/check_world_boundaries.py tests/test_world_boundaries.py ; git commit -m "ci(world): package L1 APK and auditable acceptance evidence".

## Critères de sortie et revue

L1 livrable seulement si carte navigable et sélection fiable, boucle besoins/collecte/repos prouvée, stock jamais négatif, pause réelle, plafond sans suppression, reprise exacte et récupération d'écriture interrompue. Tests automatisés et APK doivent correspondre au même SHA ; essai matériel absent ⇒ APK expérimental avec recette restante. Ne pas déclarer le lot entièrement validé sur S22 sans cette recette.

Appliquer verification-before-completion, puis requesting-code-review sur diff BASE=376ccf33353ec101b1c424b6121eb69ecfc55f62 / HEAD réel. Revue indépendante avant toute fusion future, avec exigences et résultats exacts. Corriger les blocages critiques/majeurs, signaler les limites. Aucune demande de reviewer GitHub ni message à un tiers sans instruction explicite.

## Handoff

Plan écrit et auto-relu contre le cahier des charges. Aucun de ses tests n'est actuellement implémenté. Exécution native recommandée, car les tâches partagent des contrats séquentiels et le coût doit rester maîtrisé. Une autre méthode reste un choix de Tivini. La validation demandée porte sur l'architecture Flutter provisoire, les paramètres proposés et le périmètre L1 ; elle ne vaut pas autorisation de fusion, dépenses ou déploiement VPS.
