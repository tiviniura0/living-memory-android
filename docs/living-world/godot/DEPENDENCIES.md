# Dépendances Godot — candidat vérifié en compilation

Source des valeurs : artefact de l'exécution [41036150448](https://github.com/tiviniura0/living-memory-android/actions/runs/41036150448/artifacts/12968097316), SHA source `4801903664c75f5fc1c492bd701c8a311e02a20d`.

| Élément | Version ou configuration observée |
| --- | --- |
| Flutter / Dart | 3.47.3 / 3.13.3 |
| Java | Temurin 17.0.21+9 |
| Gradle / AGP | 9.3.1 / 9.1.0 |
| Plugin Kotlin Android déclaré | 2.4.0 |
| Godot CLI / AAR / templates | 4.5.1 stable |
| CLI complet | 4.5.1.stable.official.f62fdbde1 |
| Coordinate AAR | org.godotengine:godot:4.5.1.stable |
| minSdk de la sonde | 30 |
| ABI de l'APK inspecté | arm64-v8a uniquement |
| Bibliothèque présente | lib/arm64-v8a/libgodot_android.so |

## SHA256 observés

```text
02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd  Godot_v4.5.1-stable_linux.x86_64.zip
1998af37f1387684e2c211cdb483daf492fc64dc6b12096bddcdca25b6910c86  Godot_v4.5.1-stable_export_templates.tpz
d0270df038268e1760fa4093007c50d98e63ead60a607b8b586dc761d63a069d  godot-4.5.1.stable.pom
84b292c05930ceb601b691b606d350f8ddd041783b514246e95e47ee6efabab6  godot-4.5.1.stable.aar
```

Les deux archives Godot ont été contrôlées contre les SHA512 publiés dans la release officielle, avant exécution du CLI. Les SHA256 Maven sont des empreintes observées, pas une preuve indépendante d'intégrité fournie par un tiers. Le gel final du host doit réutiliser ces valeurs ou documenter explicitement tout changement de version et relancer les contrôles adaptés.

Sources : https://github.com/godotengine/godot-builds/releases/tag/4.5.1-stable et https://repo.maven.apache.org/maven2/org/godotengine/godot/4.5.1.stable/ .

Licence du code officiel vérifiée : MIT, présente dans les en-têtes GodotHost.java/GodotFragment.java de 4.5.1-stable. Leurs sources et conditions doivent être conservées lors de la livraison. Les notices des composants transitifs restent à contrôler pour le host réel.
La page sécurité officielle consultée ne présente pas d'avis public publié ; cela ne prouve pas l'absence de vulnérabilités. Le candidat demeure validé seulement pour la sonde de compilation, pas pour une livraison de production.
