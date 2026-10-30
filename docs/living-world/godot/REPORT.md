# Tâche 1 — hôte Godot Android : livraison expérimentale partielle

Date : 30 octobre 2026. Branche exclusive : `work/living-world-godot2d`.

**Statut : INCOMPLÈTE.** Le premier chargement et le trajet Flutter ↔ Android ↔ Godot sont vérifiés sur un émulateur Android réel x86_64. Deux critères natifs de cycle de vie échouent encore : vingt réouvertures et recréation de l'Activity. Il n'est donc pas établi que l'intégration soit opérationnelle au sens du plan. Le blocage ne dépend pas de l'absence d'un téléphone.

## Périmètre réellement livré

Plugin Flutter local, PlatformView hybride, hôte officiel `GodotFragment` dans une `FlutterFragmentActivity`, singleton Godot et scène GDScript de test. Les événements ready/version et l'écho proviennent du moteur réel. Canaux par vue, session et propriétaire contrôlés ; second propriétaire refusé sans arrêter le premier. Le moteur Dart World L1 et Living Memory V1.4 ne sont pas recréés.

L'APK utilise l'entrée dédiée `lib/godot_host_smoke.dart`. Il ne contient pas encore le raccordement de la carte World ou de l'application Living Memory au rendu : tâches suivantes du plan, non commencées. Le lancement standard L1 reste dans `main.dart`.

Le code applicatif de l'APK et de l'exécution native est le commit [19d8b693](https://github.com/tiviniura0/living-memory-android/commit/19d8b693ea503fdce17f244c21282881ac89c226). Le descendant [3f8c32c9](https://github.com/tiviniura0/living-memory-android/commit/3f8c32c964447ce6f1ba1441606df1ac4584487e) retire un import inutile dans un test et ajoute sa CI ciblée ; aucun changement du code applicatif Android/Dart/Godot entre ces SHA. Le commit de ce rapport modifie uniquement la documentation. [Historique complet depuis la base de reprise](https://github.com/tiviniura0/living-memory-android/compare/994675132ba7ddf52965eece193faaee5f6ae536...3f8c32c964447ce6f1ba1441606df1ac4584487e).

## Résultats finaux et preuves

- [CI native et régressions, source 19d8b693](https://github.com/tiviniura0/living-memory-android/actions/runs/41109881668) : workflow **en échec**, job regressions réussi, job task1 en échec. Les échecs ne sont pas masqués pour publier l'APK.
- [Preuves natives, journaux, XML, métadonnées APK](https://github.com/tiviniura0/living-memory-android/actions/runs/41109881668/artifacts/13004101040).
- [Régressions World et Living Memory](https://github.com/tiviniura0/living-memory-android/actions/runs/41109881668/artifacts/13002808135).
- [CI ciblée des contrats Flutter, source 3f8c32c9](https://github.com/tiviniura0/living-memory-android/actions/runs/41110248271) : **réussie**, cinq tests et analyse sans issue ; [preuves](https://github.com/tiviniura0/living-memory-android/actions/runs/41110248271/artifacts/13002129128).

| Vérification | Résultat observé | Limite / preuve |
| --- | --- | --- |
| Python : frontières, coque non destructive, APK/ABI/libflutter/libgodot/PCK | 9 réussis, CI et contrôle local final | Contrôles de fichiers, pas exécution native |
| Observateur Flutter | 10 réussis ; analyse sans issue | Source 19d8b693 |
| Plugin Flutter : canaux et widget | 5 réussis | Fixtures de plateforme explicites |
| Analyse plugin | Une info `unnecessary_import` fait échouer l'étape au SHA 19d8b693 | Corrigée et analyse verte au SHA 3f8c32c9 ; ne pas présenter tout le premier workflow comme vert |
| `realGodotReadyHasEngineVersion` | Réussi | Godot 4.5.1 réel, singleton/version/écho |
| `secondOwnerIsRejectedWithoutKillingFirst` | Réussi | Premier moteur encore utilisable après refus |
| `resizeAndRotateKeepsHostAlive` | Réussi | Configuration/layout réellement attendus, puis écho |
| `realChannelReadyAndProbe` | Réussi | Vraie factory Flutter enregistrée et adaptateur natif |
| `reopenTwentyTimes` | **Échec** | Première réouverture refusée : `renderer_restart_required` ; test prévu pour vingt réouvertures sans reset, arrêté à la première |
| `activityRecreationKeepsHostAlive` | **Échec** | Après `ActivityScenario.recreate()` : `renderer_restart_required` |
| Intégration Flutter sur émulateur API 35/x86_64 | **1 réussi**, fermeture incluse | `flutter-native-integration.log` : vrai ready puis MethodChannel → Android → GDScript → EventChannel → Flutter |
| World portable | 47 réussis (8+23+8+8) | Contrats, core, agent runtime, persistance |
| Headless | 16 réussis + scénario 10 000 ticks | Invariants true, hash `05e332f0c6b5f5b4c1950ef0fe769f98d65c1f8550090ca152272782536acde5` |
| Living Memory Flutter | 3 121 réussis, **15 ignorés** | Journal complet conservé ; raisons explicites incluent macOS/chflags/APFS, aucune recette téléphone déduite |
| Analyses World/Memory et modules extraits | Sans issue | Artefact de régressions |
| APK ARM64 | Compilation, inspection ABI/contenu et signature réussies | **Exécution ARM64 non effectuée** |
| Capture `native/realGodotReadyHasEngineVersion/ready.png` | **Collecte échouée** | Contient `run-as: unknown package`, pas une image ; aucune preuve visuelle revendiquée |

Les six méthodes Kotlin sont exécutées dans des processus distincts pour isoler les cas. Le test est prévu pour vingt réouvertures dans un même processus et une même Activity ; il s’arrête à la première réouverture refusée, les dix-neuf suivantes ne sont donc pas exécutées. Le test de recréation utilise le véritable propriétaire ActivityAware. La collecte de capture après la commande Gradle trouve l'application désinstallée : ce défaut de collecte ne change pas les assertions natives, mais doit être corrigé avant une recette visuelle.

## APK ARM64 livré

[Télécharger l'artefact ARM64](https://github.com/tiviniura0/living-memory-android/actions/runs/41109881668/artifacts/13004101038), puis extraire `world-godot-task1-smoke-arm64.apk`. Les artefacts de cette CI ont une rétention de 14 jours, expiration annoncée le 13 novembre 2026.

- Source : `19d8b693ea503fdce17f244c21282881ac89c226`.
- APK SHA256, recalculé après téléchargement : `c4b08f1323e2214ea83b8407c23466d14159a92c35f2d6d0137b269798689596`.
- ABI unique : `arm64-v8a` ; `libgodot_android.so`, `libflutter.so` et `world_godot.pck` présents.
- Bibliothèque Godot SHA256 : `9e10c5ebda9bb629c671929441cdde3b4a8ab0e5542fc7e88de8d71f2b9840db`.
- PCK SHA256 : `4652b50ff332a2d0ca554e129a37ddc5d89d1963dc196237679dd1c6be109926`.
- Signature v2 vérifiée, certificat Android Debug SHA256 : `929ddb7ffb7f6a5d182292135a0217fd6edb823c7dcf4dd8284dc1cc9907911d`.
- Package `com.tivini.livingworld`, minSdk 30, compile/target 36. Voir [INSTALL_S22.md](INSTALL_S22.md) et [BUILD.md](BUILD.md).

L'AAR officiel contient aussi x86_64 : c'est cette architecture qui a permis les tests instrumentés sans téléphone. L'APK livré est reconstruit séparément en ARM64 et copié vers son chemin d'upload uniquement après inspection et vérification de signature. `native_execution_verified: false` dans ses métadonnées désigne honnêtement l'absence d'exécution de cet APK ARM64.

## TDD : RED observés avant implémentation

| Étape | RED comportemental constaté | Implémentation ensuite |
| --- | --- | --- |
| Contrôleur Flutter | [41099591373](https://github.com/tiviniura0/living-memory-android/actions/runs/41099591373), source 01cf9e7 : appels/événements attendus absents | 792e113 |
| Hôte et scène | [41100676008](https://github.com/tiviniura0/living-memory-android/actions/runs/41100676008), ca86a539 : quatre tests compilés, absence de vrai ready sous 20 s | 0ec28cc |
| Widget hybride | [41101055542](https://github.com/tiviniura0/living-memory-android/actions/runs/41101055542), 792e113 : chargement et message Android-only absents | 414d6ed |
| Adaptateur/factory natifs | [41102786190](https://github.com/tiviniura0/living-memory-android/actions/runs/41102786190), 5d1fd8de : `realChannelReadyAndProbe` compilé mais aucun ready | 1961e8e |
| Annulation EventChannel au démontage réel | [41107735770](https://github.com/tiviniura0/living-memory-android/actions/runs/41107735770), a2b02dee : ready/écho atteints, puis `MissingPluginException` sur cancel | 19d8b693 ; GREEN intégré final |
| Préparation non destructive / conditionnement | RED locaux sur remplacement de coque et entrées APK manquantes, puis GREEN | Recettes Python maintenues, neuf tests finaux |

Les erreurs antérieures de compilation (résolution AndroidX runner, import `PlatformViewHitTestBehavior`) ne sont **pas** comptées comme RED comportementaux. Les runs annulés en file d'attente ne sont pas comptés comme tests exécutés. L'historique Git conserve les commits intermédiaires et les workflows conservent les journaux disponibles.

## Préservation, revue et prochaine étape

Contrôle final : aucun diff depuis la base de reprise `994675132ba7ddf52965eece193faaee5f6ae536` dans les sept packages des moteurs World/Memory ni dans `samples/litert/flutter`. Les neuf autres références de branche, dont main, sont identiques au relevé initial. Aucun merge ni modification de branche stable.

La [revue indépendante](REVIEW.md) a fait corriger le test Flutter complet, l'isolation de l'upload ARM64 et les recettes de rotation/recréation. Le test intégré a ensuite détecté le désenregistrement trop précoce d'EventChannel ; correction vérifiée sur émulateur, sans filtrer les erreurs du test. Aucun accord de merge ni validation de production n'est déduit de cette revue.

**Reste bloquant en tâche 1 :** définir et vérifier un cycle de vie Godot 4.5.1 qui conserve ou rétablit un moteur utilisable lors des fermetures et recréations. Le garde-fou actuel refuse explicitement un moteur détruit au lieu de réutiliser son état JNI. Les deux tests doivent devenir verts sans redémarrer artificiellement le processus entre les vingt ouvertures. Il faut aussi reprendre la collecte de capture pendant que l'application est installée.

Non exécutés : installation et exécution ARM64/S22, recette visuelle native valide, performance/FPS/PSS/fuites et longs cycles, cohabitation avec modèle d'inférence chargé, chemins privés d'erreur d'initialisation. Les tâches 2–7, le DTO de frames et le raccordement des hôtes World/Memory ne sont pas engagés. La tâche 1 n'est pas cochée terminée.
