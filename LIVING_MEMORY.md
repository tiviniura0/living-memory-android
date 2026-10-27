# Living Memory Android

## V1.1 Auto-Memory — livraison expérimentale figée

- [APK expérimental](https://github.com/tiviniura0/living-memory-android/actions/runs/40480260704/artifacts/12723352241).
- [Rapport final, tests et limites](docs/living-memory/V1_1_REPORT.md).
- [Essai sur le S22 Ultra](docs/living-memory/V1_1_PHONE_CHECKLIST.md).
- Source testée : `89de7bd6` ; **2966 tests réussis, 15 ignorés**, analyse propre.
- Source compilée identique, hash/signature v2/ABI/modèle contrôlés séparément.

**Important : le certificat de cet APK diffère de celui de V1. Ne pas désinstaller
V1 pour contourner le refus de mise à jour : ses données seraient perdues.**
L’APK sert à un essai sur installation vierge. Le rapport distingue migration
SQLite testée et installation Android non réalisée sur téléphone.

La branche `work/living-memory-v1.1-apk` fige la livraison ; la branche demandée
`work/living-memory-v1.1-auto-memory` contient ensuite d’autres travaux en cours,
préservés et non couverts par cette validation. Aucune fusion dans main ou V1.

## Historique V1

Extension locale du projet existant `samples/litert/flutter`, pour Android
arm64 API 30+ et un premier essai sur Galaxy S22 Ultra 12 Go.

- [Rapport de non-régression](docs/living-memory/NON_REGRESSION.md)
- [Télécharger l'archive APK](https://github.com/tiviniura0/living-memory-android/actions/runs/40434835372/artifacts/12704446999)
- [Installation depuis le téléphone](docs/living-memory/INSTALL_S22.md)
- [Audit des modèles et dépendances](docs/living-memory/AUDIT.md)
- [Architecture de mémoire par agent](docs/living-memory/LIVING_WORLD_ARCHITECTURE.md)
- [État actuel et preuves](docs/living-memory/CURRENT_STATE.md)
- [Conception](docs/living-memory/DESIGN.md)

L'écran Living Memory ajoute TXT/PDF texte, notes, SQLite privé, recherche
sémantique et passages citables. La génération et les embeddings réutilisent
Gemma 4 E2B et EmbeddingGemma 2 par LiteRT-LM. Les démos originales sont conservées.

Les tests du moteur sémantique réel et de l'APK sur le téléphone sont distincts
des tests unitaires. La mémoire n'est pas encore un monde autonome.
