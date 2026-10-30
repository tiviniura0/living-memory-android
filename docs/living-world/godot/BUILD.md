# Construire et tester l'hôte Godot — tâche 1

Branche exclusive : `work/living-world-godot2d`. SDK Flutter 3.47.3 / Dart 3.13.3, Java 17, Godot CLI et AAR 4.5.1 stable. Les empreintes officielles vérifiées et leur provenance sont dans [DEPENDENCIES.md](DEPENDENCIES.md).

## APK ARM64 de la scène de test

Depuis la racine du dépôt, avec le CLI vérifié dans GODOT_BIN :

```bash
bash scripts/build_world_godot.sh
bash scripts/prepare_world_android.sh
cd apps/world_observer
flutter pub get --enforce-lockfile
flutter build apk --debug --target-platform android-arm64 -t lib/godot_host_smoke.dart
cd ../..
python3 scripts/inspect_world_godot_apk.py apps/world_observer/build/app/outputs/flutter-apk/app-debug.apk evidence-arm64.json
```

`prepare_world_android.sh` vérifie la coque suivie ; il ne régénère plus les fichiers Gradle ou MainActivity. Le PCK est placé dans les assets générés du nouveau plugin, sans copier dans les assets de modèles de Living Memory.

L'entrée `lib/godot_host_smoke.dart` est dédiée au test de l'hôte. L'entrée L1 `lib/main.dart`, la simulation et les fichiers de mémoire sont conservés. Le raccordement de la carte et de Living Memory au rendu appartient aux tâches suivantes du plan.

## Instrumentation compatible sans téléphone

L'AAR officiel 4.5.1 contient une bibliothèque x86_64. La CI construit donc un APK x86_64 pour un émulateur API 35/x86_64, avec le même AAR et le même PCK. L'APK livré est reconstruit séparément en ARM64, puis inspecté et signé avant copie vers le chemin d'upload dédié.

```bash
cd apps/world_observer
ORG_GRADLE_PROJECT_godotTestAbi=x86_64 flutter build apk --debug --target-platform android-x64
cd android
./gradlew :app:assembleDebugAndroidTest -PgodotTestAbi=x86_64
cd ../../..
bash scripts/test_world_godot_native.sh
```

Ces commandes d'instrumentation sont destinées à l'émulateur jetable de la CI. Le script lance chaque méthode Kotlin dans un processus cible distinct pour isoler les résultats. Les vingt ouvertures restent dans un seul processus et une seule Activity à l'intérieur de `reopenTwentyTimes`. Le test de recréation utilise la factory réellement enregistrée et le nettoyage ActivityAware. Le test Dart d'intégration traverse le trajet Flutter → MethodChannel → Android → GDScript → EventChannel → Flutter.

Un test ou timeout non réussi conserve un code de sortie non nul. Un refus explicite `renderer_restart_required` n'est pas compté comme une réouverture réussie. La tâche 1 exige encore les résultats de ces gates, même si le premier chargement fonctionne.

## Vérifications séparées

- Python : conservation de la coque, frontières, ABI/PCK/libgodot/libflutter et empreintes APK.
- Flutter unitaire : canaux et widget avec doubles de plateforme explicites ; aucune preuve native déduite de ces fixtures.
- Kotlin instrumenté : moteur Godot réel et callbacks de la scène.
- Flutter intégré sur émulateur : factory, PlatformView hybride, BinaryMessenger, ready et écho réels.
- Régressions : suites World portables, headless 10000 ticks, analyses des modules extraits, suite Flutter complète Living Memory.
- ARM64 : compilation et conditionnement de l'APK ; une compilation n'est pas une exécution sur ARM64/S22.

Les liens et le statut précis figurent dans [REPORT.md](REPORT.md). Les gros journaux et captures restent dans les artefacts CI liés au SHA source.
