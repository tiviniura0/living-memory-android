# Préparation GitHub Actions Godot — résultat vérifié

Date : 29 octobre 2026, Tahiti.

## Résultat actuel

La préparation est **RÉUSSIE** au commit `4801903664c75f5fc1c492bd701c8a311e02a20d`.
- Exécution : https://github.com/tiviniura0/living-memory-android/actions/runs/41036150448
- Preuves : https://github.com/tiviniura0/living-memory-android/actions/runs/41036150448/artifacts/12968097316
- SHA256 du ZIP des preuves : `239fc5a46b50c019feb24d08e82d1bc389ba98406e0c55206a628adc7054ad30`.

Le blocage de déclenchement décrit par la version précédente de ce document est levé : l'utilisateur a autorisé le push sur la seule branche Godot, limité au chemin du workflow.
`workflow_dispatch`, `contents: read`, checkout sans credentials persistants et garde sur la branche Godot sont conservés.
Aucun secret ajouté, aucune branche stable modifiée.

## Exécutions et corrections

| Commit | Exécution | Résultat | Preuves |
| --- | --- | --- | --- |
| b61193afa0bd1a4616f62ef70e62e8f59b2ef429 | https://github.com/tiviniura0/living-memory-android/actions/runs/41035347115 | Échec : sdkmanager absent du PATH, exit 127 | https://github.com/tiviniura0/living-memory-android/actions/runs/41035347115/artifacts/12967178899 |
| 7a4e819b6b3e90cd6174022ce3a6afd75c4791ba | https://github.com/tiviniura0/living-memory-android/actions/runs/41035578784 | APK compilé ; assertion ABI échouée : arm64-v8a, armeabi-v7a, x86_64 | https://github.com/tiviniura0/living-memory-android/actions/runs/41035578784/artifacts/12968411596 |
| 4801903664c75f5fc1c492bd701c8a311e02a20d | https://github.com/tiviniura0/living-memory-android/actions/runs/41036150448 | Préparation complète réussie ; ARM64 seul | https://github.com/tiviniura0/living-memory-android/actions/runs/41036150448/artifacts/12968097316 |

Corrections minimales : localisation de sdkmanager via ANDROID_HOME/ANDROID_SDK_ROOT et filtre Gradle `ndk.abiFilters` ARM64. L'assertion stricte ABI a été conservée. Aucune relance à l'identique après échec.

## Vérifications réellement effectuées

- Runner GitHub Ubuntu 24.04 ; permissions effectives Contents: read, Metadata: read.
- Flutter 3.47.3, Dart 3.13.3, Temurin Java 17.0.21.
- Android SDK observé par flutter doctor : 37.0.0 ; configuration compileSdk conservée sous le contrôle de Flutter.
- CLI officiel Godot 4.5.1.stable.official.f62fdbde1 et templates téléchargés ; deux contrôles SHA512 publiés réussis.
- POM/AAR officiel `org.godotengine:godot:4.5.1.stable` téléchargés depuis Maven Central.
- Résolution transitive et compilation réelle d'une application Flutter jetable avec ce Godot AAR, minSdk 30.
- Gradle 9.3.1, AGP 9.1.0 et plugin Kotlin déclaré 2.4.0 dans la coque générée ; ce dernier diffère de la version Kotlin 2.2.21 intégrée à Gradle.
- Inspection ZIP de l'APK : ABI exacte `["arm64-v8a"]`, présence de `lib/arm64-v8a/libgodot_android.so`.
- SHA256 de l'APK de sonde : `e3ff204fcef711aa8b4b864da4c0a9df795ea65e4bde79b152ef7e659bbd23c4`.
- Journaux et métadonnées conservés dans l'artefact CI, puis lus pour préparer DEPENDENCIES.md.

La sonde est jetable : elle ne remplace ni l'observateur ni Living Memory, n'héberge aucune scène et ne constitue pas un APK Living World livrable. Son APK n'est pas conservé comme artefact installable ; le ZIP contient les preuves, configurations et empreintes.
Le succès prouve une compatibilité de résolution/compilation de cette combinaison, pas le fonctionnement natif ou matériel.

## Tâche 1 commencée, barrière native non franchie

Reprise directe du plan existant, sans nouvel audit ni brainstorming.
Travaux effectués : contrôle des dépendances et des API GodotHost/GodotFragment/Godot.kt de la version exacte, conservation des empreintes et examen de la cible native disponible.
Le plugin, le PCK, la scène, les tests d'instrumentation et le rendu ne sont **pas implémentés** par cette préparation.

Preuve de l'absence de cible Android dans cette exécution : `flutter-doctor.txt` énumère uniquement Linux (linux-x64) et Chrome. Aucun téléphone ou émulateur Android n'est connecté. Aucune cible ARM64 d'instrumentation n'est configurée.
Cela bloque l'exécution du RED natif exigé par le plan avant implémentation du host ; aucun échec de compilation ne sera présenté comme ce RED.
Le skill TDD exige : « NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST ». La préparation n'a pas inventé de ready ni substitué une simulation au moteur.
Les quatre tests restent à écrire/exécuter : realGodotReadyHasEngineVersion, secondOwnerIsRejectedWithoutKillingFirst, reopenTwentyTimes, resizeAndRotateKeepsHostAlive.
Tâche 1 **NON TERMINÉE**. Tâches suivantes non commencées ; jalon natif et recette S22 non validés.

Pour reprendre : fournir une cible Android ARM64 accessible au runner de test (par exemple un runner dédié relié au S22 par ADB), puis exécuter les étapes RED/GREEN de la tâche 1. Ne pas inscrire aveuglément un label self-hosted qui mettrait le job indéfiniment en attente. Aucun runner ni appareil personnel n'est configuré par cette mission.

## Sources ciblées

- Plan : docs/superpowers/plans/2026-10-29-living-world-godot2d.md, tâche 1.
- https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/java/lib/src/org/godotengine/godot/GodotHost.java
- https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/java/lib/src/org/godotengine/godot/GodotFragment.java
- https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/java/lib/src/org/godotengine/godot/Godot.kt
- https://github.com/godotengine/godot/security : page consultée sans avis public publié ; ce constat ne vaut pas audit des dépendances transitives.
- https://godotengine.org/download/archive/ : 4.5.2 existe ; aucune montée silencieuse depuis le candidat 4.5.1 du plan. Approbation finale de version pour le host toujours à terminer.
