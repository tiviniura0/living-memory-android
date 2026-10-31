# Living World AI + Godot 2D — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Une revue indépendante utilisera superpowers:requesting-code-review avant livraison.

**Goal:** Remplacer le rendu géométrique du monde existant par Godot 2D isométrique sur Android, sans remplacer la simulation Dart ni Living Memory.

**Architecture:** Flutter conserve les écrans et commandes ; un plugin Android local héberge la bibliothèque officielle Godot dans une PlatformView en composition hybride. Un DTO visuel immuable alimente Godot depuis WorldController ; Godot renvoie uniquement des événements de présentation. Les deux hôtes existants sont raccordés, chacun avec sa simulation et son stockage actuels.

**Tech Stack:** Dart pur, Flutter 3.47.3 (version du workflow existant), Kotlin/Java 17, bibliothèque Android Godot officielle, GDScript 2D Compatibility, ARM64. Version Godot candidate : 4.5.1.stable ; sa disponibilité, ses correctifs de sécurité et ses contraintes transitives doivent être vérifiés en tâche 1 avant gel commun AAR/CLI/templates. Aucun numéro « latest » ni mise à jour silencieuse.

**Spec:** Mission utilisateur « MISSION — Superpowers : Living World AI + Godot 2D », reproduite sous forme d'exigences ci-dessous ; périmètre historique : `docs/superpowers/specs/2026-10-27-living-world-l1-design.md`, `docs/superpowers/specs/2026-10-28-living-memory-v1.4-design.md`. La présente mission remplace le choix de rendu provisoire Flutter ; elle ne rouvre pas les choix fonctionnels.

**Statut :** Plan validé par la mission de reprise. Tâche 1 en cours, livraison partielle au 30 octobre 2026 : hôte et APK ARM64 produits, deux gates de cycle de vie en échec. Voir `docs/living-world/godot/REPORT.md`. Tâches 2–7 non commencées.

## Global Constraints

- « Ne recréer aucun moteur existant. » Utiliser Godot officiel, WorldCore, LocalAgentRunner, WorldSession et LivingWorldMemory existants.
- « Préserver les mémoires, la simulation et les données. » Aucun changement du schéma SQLite, du codec de sauvegarde, des chemins de stockage, des règles, du RNG ou des identifiants de monde/agent.
- « Utiliser Godot directement pour le rendu. » Aucune imitation en CustomPainter, WebView, capture vidéo ou sprites affichés par Flutter sur Android.
- « Privilégier les ressources graphiques existantes sous licence compatible. » Pas de fichiers ou de sprites propriétaires Age of Empires II. Style RTS isométrique médiéval ; aucune promesse de reproduction artistique exacte.
- « Ne pas modifier les branches stables. » Base figée `e28e1f4cc0f763e0cd52227f70372594cc32d776`, référence `work/living-memory-v1.4-extensions`. Travail exclusivement dans `work/living-world-godot2d`, sans merge.
- « Limiter les relectures globales et les dépenses de tokens. » Lire ce plan, le diff depuis la base et les fichiers de la tâche ; ne pas réauditer tout LiteRT. Réutiliser les audits V1.3.1. Aucun service payant, cloud ou abonnement ajouté.
- « Ne déclarer aucun test réussi sans preuve. » Logs associés au SHA ; séparer tests simulés, exécution native, compilation et recette S22.
- « Après validation du plan, exécute les tâches TDD dans une branche isolée. » Ne pas commencer la tâche 1 avant accord sur ce document.
- Hôte Memory : conserver applicationId `com.google.ai.edge.examples.litert_edge_demos`, minSdk 30, ARM64 seul, signature et contrôles de téléchargement existants. Aucun contournement de signature ni désinstallation pour tester.
- L'observateur autonome reste une application distincte, sans permission personnelle. Ne pas lui donner accès à la base Memory d'une autre application.
- Cette mission n'ajoute ni conversations génératives, ni constructions fonctionnelles, ni nouvel ordonnanceur IA. Les décors éventuels sont identifiés comme visuels.

## Review Focus

1. Réouverture, redimensionnement et recréation Android : une seule instance Godot ; pas de crash, fuite de surface ou destruction de Flutter (tâches 1, 4 et 6).
2. Échec de checkpoint ou d'ingestion mémoire : le rendu ne contourne jamais le verrou `_needsSync` et ne fait pas avancer les habitants (tâche 6).
3. Restauration vers un tick/revision inférieur et messages retardés : nouvelle génération de rendu ; aucun ancien état ou événement ne contamine le monde réactivé (tâches 2, 4 et 6).
4. Gestes sur la carte dans le ListView Memory, clavier et retour système : pan/pincement ne sélectionnent pas un habitant et les contrôles Flutter restent accessibles (tâches 4, 5 et 6).
5. Atlas manquant, message malformé ou natif indisponible : erreur visible, données intactes, aucune réinitialisation ni repli silencieux vers des ronds (tâches 2, 3, 4 et 6).

## Audit ciblé au commit de base

Inventaire Git complet des chemins, lectures ciblées des modules ci-dessous. Aucun `AGENTS.md`, `project.godot`, `.gd`, `.tscn` ou index `graphify-out` suivi dans cette référence. Aucun projet Godot local à réutiliser identifié : intégrer la distribution officielle, sans réécrire le moteur. Ne pas prétendre avoir examiné d'autres branches ou un projet Godot externe non fourni.

| Fichier réel | Interface / conséquence |
|---|---|
| `packages/world_contracts/lib/src/world_types.dart` | `WorldView(snapshot, selectedAgentId, requestedSpeed, effectiveSpeed, mode)` ; `GridPos(x,y)` ; monde immuable. Dimensions 1..256 ; plafond 1..1000, sans garantie de performance à 1000. |
| `packages/world_core/lib/src/world_factory.dart` | Création existante : carte par défaut 64×64, une ressource nourriture, obstacles déterministes. Pas de bâtiments fonctionnels. |
| `apps/world_observer/lib/world_controller.dart` | `view: ValueNotifier<WorldView>`, `publish()`, `selectAgent(String?)`, `restore()`. Le contrôleur reste l'autorité de sélection. |
| `apps/world_observer/lib/runtime/world_session.dart` | Sauvegarde/import sérialisés, remplacement de core/runner lors de restore. Ne pas retenir un ancien core dans le pont. |
| `apps/world_observer/lib/runtime/world_loop.dart` | Avance existante 4 ticks/s, vitesses 1/2/4, rattrapage limité à 8 ticks ; aucune boucle de simulation côté Godot. |
| `apps/world_observer/lib/map/world_viewport.dart` | Point de remplacement commun ; reçoit controller/camera et utilise actuellement CustomPaint. |
| `apps/world_observer/lib/world_app.dart` | Ticker Flutter, gestes et commandes de suivi/recentrage via CameraController ; adapter ces commandes au rendu Godot sans créer une seconde horloge. |
| `apps/world_observer/lib/runtime/world_lifecycle.dart` | Mise en pause et sauvegarde au passage en arrière-plan ; reprise manuelle. |
| `samples/litert/flutter/lib/living_memory/world_memory_panel.dart` | Vrai hôte V1.4 : 2 agents initiaux, carte haute de 220 px dans un ListView. `_advance()` avance 12 ticks manuellement, `_sync()` sauvegarde puis ingère. Monde dans `living-world-v14`, base `living-world-memory-v1.db`. Pas de ticker automatique dans cet hôte. |
| `packages/living_world_memory/lib/living_world_memory.dart` | Ingestion, souvenirs privés, partage/révocation existants ; aucune mémoire ou base ne traverse le pont visuel. |
| `samples/litert/flutter/android/app/src/main/kotlin/com/google/ai/edge/examples/litert_edge_demos/MainActivity.kt` | FlutterActivity ; canaux security/documents/transfer et onActivityResult existants. Un GodotFragment exige un hôte compatible fragments, à vérifier sans casser SAF. |
| `samples/litert/flutter/android/app/build.gradle.kts` | Java17, minSdk30, ARM64, protection de signature release, SQLCipher/LiteRT dans les dépendances applicatives existantes. |
| `samples/litert/flutter/android/settings.gradle.kts` | AGP9.1.0, Kotlin2.4.0 déclarés par le dépôt ; compatibilité Godot à prouver par résolution et compilation. |
| `scripts/prepare_world_android.sh` | Régénère actuellement toute la coque Android autonome sauf son manifeste ; une modification Gradle directe serait écrasée. Corriger ce flux en tâche 1. |
| `.github/workflows/world-l1.yml`, `living-memory-v14.yml`, `build-apk.yml` | Filtres de branches actuels n'incluent pas la nouvelle branche ; ajouter un workflow Godot dédié. |

### Contraintes officielles et choix d'intégration

- Godot est distribué en AAR Maven ; l'hôte Android gère son cycle de vie et les échanges via GodotHost/GodotPlugin. Une seule instance par processus dans la documentation 4.5 ; avertissement sur orientation/redimensionnement. Sources [G1], [G2].
- Choix : un plugin Flutter local réutilisable `packages/living_world_godot`, `GodotFragment` dans une vue Android à identifiant stable ; hôte `FlutterFragmentActivity` si le spike valide son cycle complet. Ne pas déplacer la simulation dans une Activity séparée : on conserverait difficilement la boucle Dart et le verrou mémoire.
- Composition hybride explicite avec `PlatformViewLink`, `AndroidViewSurface`, `PlatformViewsService.initExpensiveAndroidView`. Ne pas compter sur TLHC pour SurfaceView ; ne pas activer HCPP expérimental. Source [F1].
- Godot `gl_compatibility`, `Camera2D`, `TileMapLayer`, `Sprite2D/AnimatedSprite2D`. Importer les textures puis exporter un PCK ; copier uniquement ce PCK dans les assets Android, chargé par `--main-pack`. Version CLI/templates/AAR identique et verrouillée. Ne pas copier le cache éditeur brut.
- Transmission locale MethodChannel/EventChannel, sans port réseau, serveur HTTP ni lecture SQLite par Godot. GDScript reçoit via le plugin Godot sur son thread de rendu ; les appels Android/Flutter retournent au thread UI.
- Les capacités exactes de redimensionnement et coexistence des runtimes sont **non vérifiées**. La tâche 1 est un jalon bloquant : en cas d'échec reproductible, fournir preuves et correction ciblée du plan avant développement artistique étendu.

### Ressources proposées et contrôle de provenance

Choix de départ : Kenney **Isometric Tiles Landscape** pour sol/nature [A1], **Isometric Tiles Buildings** pour décors [A2], **Isometric Dungeon Tiles** pour personnage directionnel existant [A3]. Les pages indiquent CC0 ; le troisième pack annonce 8 directions / 3 animations. La cohérence graphique médiévale doit être vérifiée sur une capture réelle ; ce ne sont pas les graphismes originaux d'AoE II.

En tâche 3 : télécharger uniquement depuis l'auteur ; sélectionner les fichiers après inspection réelle, conserver la licence incluse, URL source, date, empreinte SHA256 de l'archive et des fichiers sélectionnés. Ne pas inventer maintenant des noms de sprites non téléchargés. Le manifeste fixe ensuite le mapping exact terrain/obstacle/nourriture/agent et leurs pivots. Aucun achat nécessaire.

### Vérifications effectuées pendant cet audit

Exécutées le 29/10/2026 dans le checkout de base :

- `python3 -m unittest discover -s tests -p test_world_boundaries.py -v` : **3 tests, OK**, exit 0.
- `python3 scripts/check_world_boundaries.py` : **World boundaries: OK**, exit 0.
- `git rev-parse HEAD` : `e28e1f4cc0f763e0cd52227f70372594cc32d776`.
- Worktree isolé créé sur `work/living-world-godot2d`, HEAD égal à la base, diff suivi vide avant ce document. Les fichiers temporaires non suivis du clone initial ne sont pas importés dans ce worktree.
- `flutter`, `dart`, `godot`, `adb` absents du PATH de cet environnement. **Aucun test Dart/Flutter/Godot, build Gradle/APK ou essai téléphone effectué pour cette mission.** Les résultats V1.4 historiques restent ceux de leur rapport ; ils ne prouvent pas l'intégration Godot.

## Contrat visuel fixé pour les tâches

Nouveau package pur `packages/world_render_contracts`, dépendant uniquement de world_contracts. API `RenderFrame.fromWorldView(WorldView view, {required int generation, required int sequence})`, `Map<String,Object?> toJson()` et `RenderFrame.fromJson(Map<String,Object?> json)`.

JSON strict : `schemaVersion:1`, `worldId`, `generation`, `sequence`, `tick`, `revision`, `width`, `height`, `blockedCells:[{x,y}]`, `resources:[{id,x,y,food}]`, `agents:[{id,name,x,y,action}]`, `selectedAgentId`. Aucun eventLog, prompt, souvenir, profil d'embedding, clé, chemin, RNG ni commande de simulation. Bornes des coordonnées/configurations reprises des contrats World ; entiers 0..2^53−1 pour les compteurs, génération >=1 ; au plus 1000 agents. Trame encodée UTF-8 <=1 MiB sinon erreur explicite sans tronquer le monde.

Session du pont : `open` retourne un `sessionId` opaque ; tous les événements l'incluent. Un `ready` confirme le script Godot chargé ; `applyFrame` attend `frameApplied(generation,sequence)` après application effective. Au plus une trame en vol et une trame récente en attente (remplacement, pas accumulation), délai d'ACK 5s puis état d'erreur et action « Réessayer ». Recréation/réouverture crée une nouvelle session ; changement/restauration/import du monde incrémente génération, y compris restauration d'une révision inférieure. Ne pas comparer revision entre générations. Sélection à tick identique a une nouvelle sequence.

Sorties autorisées : `ready`, `frameApplied`, `agentSelected` (id nullable), `error`. L'événement de sélection porte session/generation/sequence et n'est accepté que pour la trame actuellement acquittée et un agent encore présent dans le controller courant. Aucun `advance`, `save`, `ingest`, chemin ou script arbitraire accepté depuis Godot.

Caméra : API Flutter `centerOn(GridPos)`, `setFollow(String?)`, `resetCamera()` ; Godot seul applique pan/zoom. Zoom borné 0.5..3.0, suivi annulé par pan manuel ; reset cadre les limites de la carte. Projection des centres de cellules `((x-y)*32, (x+y)*16)` pour losanges 64×32 ; dimensions/pivots des sprites adaptés par mapping, sans déformer les personnages.

## Séquence d'implémentation TDD

Chaque tâche : lire uniquement ses fichiers et interfaces dépendantes ; tests RED exécutés et échec attendu conservé, implémentation minimale, GREEN puis refactor et commit. Les commandes ci-dessous sont à lancer depuis la racine sauf mention contraire. Les journaux vont dans `docs/living-world/godot/evidence/` ou dans les artefacts CI lourds référencés par SHA. Une commande décrite n'est pas une commande exécutée.

### Task 1: Prouver l'hébergement Android réel avant de développer le rendu

**Files**
- Create: `packages/living_world_godot/pubspec.yaml`, `lib/living_world_godot.dart`, `android/build.gradle`, `android/src/main/AndroidManifest.xml`.
- Create: `packages/living_world_godot/android/src/main/kotlin/com/tivini/livingworld/godot/LivingWorldGodotPlugin.kt`, `GodotHostView.kt`, `GodotRenderPlugin.kt`.
- Create: `packages/living_world_godot/android/src/androidTest/kotlin/com/tivini/livingworld/godot/GodotHostTest.kt`.
- Create: `renderers/godot2d/project.godot`, `scenes/world.tscn`, `scripts/world.gd`, `export_presets.cfg` (scène vide de smoke test uniquement à ce stade).
- Create: `scripts/build_world_godot.sh`, `.github/workflows/world-godot.yml`, `docs/living-world/godot/DEPENDENCIES.md`.
- Modify: `apps/world_observer/pubspec.yaml`, `scripts/prepare_world_android.sh` ; suivre la coque Android autonome générée une seule fois, dont `android/app/build.gradle.kts` et `android/app/src/main/kotlin/com/tivini/livingworld/MainActivity.kt` ; les exécutions suivantes ne doivent pas l'écraser.

**Interfaces:** `LivingWorldGodotView` widget Android ; vue native `living_world/godot_view`, canaux `living_world/godot/methods/<viewId>` et `living_world/godot/events/<viewId>`. GodotHostView porte les interfaces officielles, une instance unique par processus et l'état de session. Refuser proprement un second propriétaire simultané.

- [ ] Écrire test d'instrumentation : `realGodotReadyHasEngineVersion`, `secondOwnerIsRejectedWithoutKillingFirst`, `reopenTwentyTimes`, `resizeAndRotateKeepsHostAlive`. Assertions : singleton plugin présent dans GDScript, ready issu de Godot, 20 ouvertures/fermetures sans quitter Flutter ; deuxième vue reçoit `renderer_in_use`. Ne pas simuler le ready natif.
- [ ] Lancer les tests avant implémentation ; conserver l'échec dû à l'absence du host. La compilation manquante d'un nouveau symbole seule ne prouve pas le comportement RED ; après squelette compilable, exécuter le test et observer l'absence de ready.
- [ ] Vérifier Maven/POM, licence MIT et avis de sécurité ; geler AAR/CLI/templates et SHA256 dans DEPENDENCIES. Résoudre avec la toolchain existante avant toute montée de version. Si 4.5.1 est inadéquat, consigner le patch officiel retenu et ses différences d'API dans ce plan avant la suite.
- [ ] Implémenter l'hébergement GodotFragment + cycle attach/detach/background/foreground. Utiliser un hôte autonome FlutterFragmentActivity. Annuler listeners/ACKs au dispose, fermer la scène sans `System.exit` ni `get_tree().quit()` qui détruirait le processus hôte. Aucune simulation dans la scène.
- [ ] Rendre `prepare_world_android.sh` non destructif : vérifier la coque suivie au lieu de la remplacer. Construire PCK importé et inclure le dossier généré d'assets par sourceSets Gradle ; ne pas copier sur les assets modèle existants.
- [ ] Workflow nouvelle branche + workflow_dispatch : installer les SDK gelés, importer/exporter la scène, compiler l'observateur, exécuter instrumentation sur cible ARM64 accessible. Si aucune cible ARM64 n'est disponible, produire le build et marquer le gate natif **bloqué**, sans passer à la tâche 3.
- [ ] GREEN : `godot --headless --path renderers/godot2d --editor --import`, `bash scripts/build_world_godot.sh`, puis dans `apps/world_observer` : `flutter build apk --debug --target-platform android-arm64` et `cd android && ./gradlew :app:connectedDebugAndroidTest`. Archiver sorties, version, logs bornés, capture et rapport instrumentation. Commit `feat: host official Godot renderer on Android`.

### Task 2: Contrat de présentation immuable et minimal

**Files:** Create `packages/world_render_contracts/pubspec.yaml`, `lib/world_render_contracts.dart`, `lib/src/render_frame.dart`, `test/render_frame_test.dart`, `test/render_protocol_test.dart`, `fixtures/world/render_frame_v1.json` ; Modify `scripts/check_world_boundaries.py`, `tests/test_world_boundaries.py` pour inclure ce package pur.

**Interfaces:** RenderFrame décrit ci-dessus ; `RenderSelection.tryParse(Map<String,Object?> json)` retourne événement typé ou null. Aucune dépendance Flutter/native dans ce package.

- [ ] RED : `framePreservesAuthoritativePositions`, `frameExcludesPrivateState`, `invalidCoordinatesRejected`, `unknownSchemaRejected`, `oversizedFrameRejected`, `emptyWorldRoundTrips`. Construire une WorldView réelle depuis la fixture existante ; vérifier l'ensemble exact des clés, positions/ids inchangés et égalité du WorldCodec avant/après projection. Tester frontières 1×1 et 256×256, ids dupliqués, chaînes malformées, compteur hors borne, sélection absente.
- [ ] Exécuter `(cd packages/world_render_contracts && dart pub get && dart test --reporter expanded)` et observer les assertions RED ; introduire uniquement les squelettes nécessaires pour exécuter les tests.
- [ ] Implémenter projection par liste blanche, validation stricte et fixture JSON commune Dart/GDScript. Écrire un test de frontière qui échoue si le package importe Flutter, Godot natif ou living_memory_core.
- [ ] GREEN : même suite, `dart analyze`, suites frontières Python. Commit `feat: define read-only world render protocol`.

### Task 3: Premier monde isométrique avec ressources existantes

**Files:** Modify `renderers/godot2d/project.godot`, `scenes/world.tscn`, `scripts/world.gd` ; Create `scripts/frame_decoder.gd`, `scripts/asset_catalog.gd`, `scripts/isometric_camera.gd`, `assets/catalog.json`, `assets/licenses/`, sprites sélectionnés sous `assets/`, `tests/render_tests.gd`, `docs/living-world/godot/ASSETS.md` ; Modify `docs/living-world/LICENSES.md`.

**Interfaces:** `FrameDecoder.decode(json_text: String) -> Dictionary` retourne `{ok,frame,error}` ; `world.apply_frame(json_text: String) -> bool` ; `IsometricCamera.center_on(cell: Vector2i)`, `set_follow(agent_id: String)`, `reset_camera()`. Signaux de la scène : `frame_applied(generation, sequence)`, `agent_selected(id)`.

- [ ] RED : `cell_1_0_projects_to_32_16`, `cell_0_1_projects_to_minus32_16`, `frame_matches_dart_fixture`, `bad_frame_leaves_last_world_unchanged`, `missing_texture_is_explicit_error`. TestSceneRunner construit la scène réelle et compare positions, nombre/ids des Sprite2D, TileMapLayer et sélection ; assertions Godot via runner qui quitte avec code non nul en cas d'échec.
- [ ] Run `godot --headless --path renderers/godot2d --script res://tests/render_tests.gd` ; observer les échecs fonctionnels avant corps d'implémentation.
- [ ] Télécharger/inspecter les packs [A1..A3], fixer les noms exacts et pivots dans catalog.json et leurs hashes/licences dans ASSETS. Si un pack ne convient pas graphiquement, ne pas le prétendre conforme : sélectionner un autre asset existant avec licence vérifiée et documenter ce choix, sans changer le moteur.
- [ ] Implémenter sol TileMapLayer isométrique, obstacles ancrés aux blockedCells, ressources à leur vraie position, personnages directionnels existants ; profondeur par pieds et Y-sort, interpolation uniquement visuelle entre deux positions acquittées, téléportation sans interpolation entre générations. Nourriture épuisée distinguée ; action reflétée sans en inventer. Pas d'obstacle visuel bloquant ajouté à une case accessible. Décors de bâtiment purement visuels en dehors des cases jouables, clairement documentés.
- [ ] GREEN headless ; capturer la scène sous rendu graphique réel en plus des tests headless. Capture 64×64 avec 2 agents et ressource, puis 5 agents ; juger lisibilité smartphone, occlusion et cohérence médiévale. Le headless seul ne valide pas l'aspect. Commit `feat: render existing world as Godot isometric scene`.

### Task 4: Pont Flutter–Godot borné, commandes caméra et cycle de vie

**Files:** Create `apps/world_observer/lib/rendering/world_render_bridge.dart`, `godot_world_viewport.dart`, `test/render_bridge_test.dart` ; Modify plugin Dart/Kotlin de tâche 1, scène GDScript et tests natifs ; Modify `apps/world_observer/pubspec.yaml` pour world_render_contracts.

**Interfaces:** `WorldRenderBridge({required WorldController controller, required RenderTransport transport})`, `Future<void> attach()`, `Future<void> resync()`, `void resetGeneration()`, `void centerOn(GridPos)`, `void setFollow(String?)`, `void resetCamera()`, `Future<void> dispose()` ; `RenderTransport` porte open/applyFrame/camera/close et flux d'événements typés. GodotWorldViewport consomme le bridge ; état visible loading/ready/error/retry. Les erreurs natif ne sont jamais des succès Dart.

- [ ] RED : `waitsForGodotReady`, `keepsOnlyNewestPendingFrame`, `missingAckBecomesErrorAfterFiveSeconds`, `oldSessionSelectionIsIgnored`, `generationAllowsLowerRevisionRestore`, `selectionAtSameRevisionIsPublished`, `disposeCancelsSubscriptions`, `renderNeverAdvancesOrWritesWorld`. Transport faux limité aux tests de file/timeout ; horloge déterministe. Tester 100 publications rapides : 1 en vol + la dernière, pas 100 buffers.
- [ ] Run `(cd apps/world_observer && flutter test test/render_bridge_test.dart --reporter expanded)` ; conserver RED.
- [ ] Implémenter les compteurs de génération/séquence, ACK réel et validation des deux côtés du canal. Programmer signaux et callbacks sur les threads Godot/UI requis par l'AAR gelé ; pas de logs de payload.
- [ ] Composition hybride explicite, ownership des gestes dans la carte, gestion de viewId/session restaurés ; background suspend le rendu, foreground renvoie le dernier état après ready, sans tick supplémentaire. Pas de frame live avant ouverture correcte.
- [ ] GREEN tests Flutter + Godot ; instrumentation `realFrameAckMatchesScene`, `oldSessionCannotSelectAgent`, `backgroundDoesNotAdvanceWorld`, `missingPackKeepsSavedFiles`. Commit `feat: connect bounded Flutter Godot render bridge`.

### Task 5: Raccorder l'observateur autonome et préserver ses contrôles

**Files:** Modify `apps/world_observer/lib/map/world_viewport.dart`, `lib/world_app.dart`, `lib/world_controller.dart`, `lib/map/camera_controller.dart` seulement si nécessaire pour router les commandes existantes ; Modify `test/selection_test.dart`, `test/camera_test.dart`, `test/lifecycle_test.dart`, `integration_test/l1_village_test.dart` ; Create `integration_test/godot_world_test.dart`.

**Interfaces:** Conserver le constructeur WorldViewport existant ; injection optionnelle de RenderTransport pour tests sans surface native. Android normal utilise Godot ; autre plateforme non implémentée affiche « Rendu Godot disponible sur Android » sans prétendre être un monde rendu. Un seul bridge par viewport.

- [ ] RED : `viewportUsesNativeGodotSurfaceOnAndroid`, `selectAgentStillUpdatesPanel`, `followAndResetReachGodotCamera`, `restoreInvalidatesOldGeneration`. Adapter les attentes de coordonnées aux cellules isométriques tout en conservant les assertions de comportement du moteur.
- [ ] Run tests ciblés puis implémenter le remplacement de WorldPainter dans ce viewport ; router suivi/recentrage vers Godot. Conserver Ticker et WorldLifecycle uniques. Signaler explicitement changement de génération après restore/import, même si la revision est identique ; ne pas déduire ce changement de l'identité de chaque snapshot.
- [ ] GREEN : `flutter test --reporter expanded`, `flutter analyze` dans l'observateur ; instrumentation écran réel : tap agent, drag, pinch, suivre, pause/vitesse, sauvegarder/restaurer, retour/réouverture, orientation et redimensionnement. Comparer WorldCodec/hash à un contrôle sans renderer au même nombre de ticks. Commit `feat: use Godot in existing world observer`.

### Task 6: Raccorder le véritable hôte Living Memory V1.4

**Files:** Modify `samples/litert/flutter/lib/living_memory/world_memory_panel.dart`, `samples/litert/flutter/pubspec.yaml`, `samples/litert/flutter/android/app/src/main/kotlin/com/google/ai/edge/examples/litert_edge_demos/MainActivity.kt` ; si requis `samples/litert/flutter/android/app/build.gradle.kts` et `android/app/src/main/AndroidManifest.xml` ; Create `test/living_memory/v14_godot_host_test.dart`, `integration_test/living_world_godot_test.dart` sous samples/litert/flutter ; Modify tests V1.4 existants seulement pour injection du transport.

**Interfaces:** Même WorldViewport/bridge que l'observateur. `_advance()` et `_sync()` conservent leur ordre et leur responsabilité. MainActivity devient FlutterFragmentActivity uniquement si nécessaire au host validé, tout en préservant configureFlutterEngine, security/documents/transfer, onActivityResult et nettoyage existants.

- [ ] RED : `rendererDoesNotAdvancePausedMemoryHost`, `failedCheckpointBlocksNextAdvance`, `failedIngestRequiresRetryWithoutDuplicateMemories`, `frameHasNoPrivateNotes`, `twoAgentsKeepPrivateAndSharedMemoriesAfterReopen`. Réutiliser les fixtures et MemoryStore réels des tests v14_world/v14_ui ; faux transport uniquement pour surface native, pas pour le stockage.
- [ ] Exécuter `flutter test test/living_memory/v14_godot_host_test.dart --reporter expanded` depuis l'application et conserver RED.
- [ ] Raccorder le rendu sans ajouter de ticker ni d'auto-ingestion. Publier après l'opération existante, préserver le blocage de `_needsSync`. Map 220px reste intégrée ; gestes carte capturés dans sa zone, scroll possible en dehors, clavier du champ note reste utilisable.
- [ ] GREEN : tous `test/living_memory/v14*_test.dart` puis suite Flutter complète de l'application, analyse, régressions SAF/security existantes. Instrumentation ARM64 : vraie scène Godot + A/B + note privée + partage + révocation + réouverture ; transfert SAF et annulation, chat avant/après fermeture de World.
- [ ] Vérifier merged manifest et dépendances natives : aucune permission ajoutée par surprise ; absence de collision libgodot/libc++/LiteRT/SQLCipher, alignement natif Android, licence et stockage. Aucun accès Godot à MemoryStore. Commit `feat: preserve V1.4 memory host with Godot rendering`.

### Task 7: Compilation, revue indépendante et dossier de livraison

**Files:** Finalize `.github/workflows/world-godot.yml` ; Create `docs/living-world/godot/REPORT.md`, `BUILD.md`, `INSTALL_S22.md`, `REVIEW.md`, `PROGRESS.md` et preuves légères ; Modify `docs/living-world/DELIVERY.md` avec lien vers ce jalon sans réécrire les preuves L1.

**Interfaces:** Artefacts séparés `world-godot-observer-<sha>`, `living-memory-godot-<sha>`, `world-godot-evidence-<sha>` avec SHA source, hashes APK/PCK/assets, versions et certificat signataire. Publication GitHub sur branche isolée ; aucun merge ou remplacement d'installation automatique.

- [ ] Compléter CI sur la nouvelle branche : tests/analyse world_contracts/world_core/agent_runtime/world_persistence/world_render_contracts, world_observer, world_headless, modules mémoire et suite Flutter Memory ; tests Godot/import/export PCK ; frontières Python et audits V1.3.1 réutilisés.
- [ ] Depuis tools/world_headless : `dart run bin/world_headless.dart --fixture ../../fixtures/world/l1_world.json --ticks 10000 --out ../../evidence/headless-godot.json` ; comparer le résultat déterministe au même contrôle sur la base, pas à une valeur réinventée.
- [ ] Construire PCK puis `flutter build apk --release --target-platform android-arm64 --split-per-abi` dans les deux hôtes. Pour Memory, réutiliser strictement la politique SIGNING existante ; opt-in debug expérimental explicite uniquement selon procédure actuelle. Documenter non-installabilité si certificat différent, ne jamais supprimer les données pour l'obtenir.
- [ ] Vérifier APK final : apksigner, aapt badging, merged manifest, ARM64, bibliothèques et PCK présents, empreintes. Audit dépendances Gradle sur l'APK Memory complet, pas seulement le plugin. Mettre les gros artefacts en GitHub Actions, pas dans git.
- [ ] Recette S22 : captures portrait/paysage, 20 réouvertures, gestes, clavier, arrière-plan, sauvegarde/reprise, deux mémoires privées et partage. Mesurer frame time et PSS du processus incluant Godot, car Flutter FrameTiming seul n'observe pas la surface Godot. Cible proposée : 30fps, p95 <=33.3ms sur monde par défaut pendant 5min ; tester 20 agents par fixture valide, sans promettre 1000 ni modifier le plafond. Comparer RAM/temps/frame à la base et tester cohabitation avec le modèle réellement chargé ; pas d'estimation annoncée comme mesure.
- [ ] Lire le template requesting-code-review, faire revoir le diff complet base..HEAD par un reviewer indépendant avec ce plan et les preuves ciblées. Corriger tout Critical/Important et rerun des vérifications concernées ; documenter les limites restantes. La revue de code n'est pas une validation matérielle.
- [ ] Verification-before-completion : vérifier diff sans changements de schémas/règles/chemins, branches stables intactes, tests frais au SHA livré, URLs exactes artefacts. REPORT distingue « réussi », « échoué », « non exécuté » et « bloqué » ; terminer sans annoncer le jalon natif validé si le gate ou la recette n'a pas tourné.
- [ ] Commit `docs: deliver verified Godot integration evidence` ; fournir liens plan, diff, APK et preuves. Pas de nouvelle demande de brainstorming.

## Sources officielles consultées le 29 octobre 2026

- [G1] https://docs.godotengine.org/en/4.5/tutorials/platform/android/android_library.html — AAR, GodotHost/GodotFragment, PCK, instance unique et avertissements de configuration.
- [G2] https://docs.godotengine.org/en/4.5/tutorials/platform/android/android_plugin.html — GodotPlugin, annotations JVM et signaux.
- [G3] https://docs.godotengine.org/en/4.5/about/system_requirements.html — renderer Compatibility ; exigences à recouper avec le runtime effectivement retenu.
- [F1] https://docs.flutter.dev/platform-integration/android/platform-views — composition hybride, limites SurfaceView et HCPP expérimental.
- [A1] https://kenney.nl/assets/isometric-tiles-landscape — CC0.
- [A2] https://kenney.nl/assets/isometric-tiles-buildings — CC0.
- [A3] https://kenney-assets.itch.io/isometric-dungeon-tiles — page de l'auteur, CC0, personnage directionnel.

## Auto-revue du plan et reprise courte

Couverture : Godot direct (1/3/4), indépendance Dart et données (2/5/6), deux hôtes (5/6), ressources sous licence (3), build/preuves/revue (7). Les cinq risques Review Focus ont chacun leurs tests nommés. API communes fixées dans Contrat visuel ; T1 peut ajuster uniquement la plomberie officielle selon la version AAR effectivement gelée, en consignant la différence avant les tâches dépendantes. L'absence actuelle d'assets téléchargés explique le gel du mapping en T3 ; aucun fichier d'asset inexistant n'est affirmé présent.

Prochaine étape après accord : exécution native par l'agent principal, TDD et commits courts ; revue indépendante au jalon final. Pour reprendre, lire ce plan puis `git diff e28e1f4cc0f763e0cd52227f70372594cc32d776...HEAD` et PROGRESS.md s'il existe. Ne pas recloner ou relire tout le dépôt sans besoin nouveau identifié.

### Ajustement ciblé T1 — cycle de vie de la surface (30 octobre 2026)

La correction 7e45cbb conserve le fragment mais détache encore la GLSurfaceView. Dans Godot 4.5.1 officiel, GLSurfaceView.onDetachedFromWindow termine le thread GL ; GodotRenderer.onRenderThreadExiting appelle GodotLib.ondestroy. Le fragment standard appelle aussi Godot.onDestroy lors d'une recréation. Les RED natifs restent les critères de décision, aucun reset de garde JNI n'est permis.

Correction candidate : fragment AndroidX retenu implémentant l'interface officielle GodotHost, racine graphique attachée une seule fois à SurfaceControlViewHost (API 30, minSdk existant), transfert des seuls SurfacePackage vers les SurfaceView de présentation. Pause/reprise et destruction finale passent par les API officielles Godot ; aucune modification du moteur/AAR/CLI, aucune permission ajoutée. Ce changement remplace uniquement la plomberie GodotFragment trop destructive ; canaux, singleton, simulation et stockage restent identiques. Il n'est validé que si les tests natifs existants, un écho après recréation et la capture réelle passent. Les gestes et performances restent à vérifier aux tâches suivantes.

Sources de la correction : [GLSurfaceView 4.5.1](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/java/lib/src/org/godotengine/godot/gl/GLSurfaceView.java), [GodotRenderer 4.5.1](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/java/lib/src/org/godotengine/godot/gl/GodotRenderer.java), [GodotHost](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/java/lib/src/org/godotengine/godot/GodotHost.java), [SurfaceControlViewHost](https://developer.android.com/reference/android/view/SurfaceControlViewHost), [SurfaceView.setChildSurfacePackage](https://developer.android.com/reference/android/view/SurfaceView#setChildSurfacePackage(android.view.SurfaceControlViewHost.SurfacePackage)).

Ajustement T1 complémentaire : la CI `41164517154` au SHA `ca89b909` valide les vingt réouvertures, la recréation, la rotation, le second propriétaire, le canal réel, l'arrière-plan et Flutter intégré. Elle révèle un RED supplémentaire : `activityFinishAndRelaunchKeepsHostAlive` échoue `renderer_restart_required`. La conservation du fragment ne couvre pas un véritable finish. L'hôte officiel devient donc un objet de processus (`ProcessGodotHost`) qui possède l'unique moteur et SCVH, garde seulement une WeakReference de l'Activity et reçoit les callbacks via un fragment temporaire. Tous les callbacks et le détachement vérifient l'identité de l'Activity courante. Le Handler UI continue à recevoir les événements sans Activity. Fermer une Activity suspend cette unique hiérarchie ; Android libère ses ressources en terminant le processus. Aucune réinitialisation JNI ni nouvelle instance moteur n'est utilisée. Cette correction attend son GREEN natif ; le test tactile ajouté séparément reste un gate distinct.
