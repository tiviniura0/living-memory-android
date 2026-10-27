# Living Memory Implementation Plan

Goal: livrer un APK local dans le dépôt existant.
Architecture: module indépendant, emprunt des moteurs actuels, SQLite privé.
Tech Stack: Flutter/Dart, sqlite3 déjà transitif, Kotlin SAF, PDFBox Android.
Spec: DESIGN.md. Exécution directe autonome autorisée par la mission.

Contraintes: préserver les démos/tests ; pas d'IA distante, frais ni documents
privés dans le dépôt ; Android arm64 API 30+ ; aucune preuve inventée.

Points de revue : agent différent, import interrompu, unicode, PDF sans texte,
modèle incompatible / manque de mémoire. Ne jamais généraliser le seuil de
pertinence des documents techniques aux documents personnels.

- [x] 1. Corriger le workflow vide, préparer plugin vendored et modèles vérifiés,
  résoudre le lock, exécuter analyse/tests/build, relever les vrais logs.
- [x] 2. Écrire les tests memory_store_test.dart et memory_chunker_test.dart.
  Interface: MemoryStore.open(path), addDocument(agentId, pages, vectors),
  search(agentId, vector), documents(agentId), deleteDocument(agentId, id).
  Exécuter les tests ; coder stockage transactionnel, filtre agent et vecteurs.
- [x] 3. Canal Android: pickDocument -> nom/pages ; pickModel -> chemin local.
  Borner les entrées, préserver les erreurs/cancel ; étendre le picker existant.
- [x] 4. Écran Living Memory: création agent, import TXT/PDF et note, recherche,
  génération neuve sans outils, sources consultables, suppression locale.
  Utiliser EmbedderService.embedDocuments/embedQuery et ConversationRepository.
- [x] 5. Exécuter format/analyse/suite complète, compiler dans Actions, inspecter
  les échecs, corriger la cause, collecter artefact et empreinte si possible.
- [x] 6. Rapport de non-régression avec résultats, blocages et procédure S22.

Vérification finale : 40434835372 (build) et 40437013088 (artefact) réussies.
L'exécution native sur S22 n'a pas été réalisée ; voir NON_REGRESSION.md.
