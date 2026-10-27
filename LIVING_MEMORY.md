# Living Memory Android

Extension locale du projet existant `samples/litert/flutter`, pour Android
arm64 API 30+ et un premier essai sur Galaxy S22 Ultra 12 Go.

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
