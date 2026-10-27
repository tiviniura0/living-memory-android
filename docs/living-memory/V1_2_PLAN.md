# V1.2 — conception et plan autorisés par la mission

Source figée : fe9c0af4acc9a2fc28fcef0c38ee5638425c778d.
V1.1 verte : https://github.com/tiviniura0/living-memory-android/actions/runs/40556412829
Aucun changement de V1.1 ou main. Exécution directe demandée.

## Audit et décisions
Application Flutter existante, LiteRT-LM via flutter_edge_ai_litertlm épinglé.
ConversationRepository, ChatModelSwitcher et ModelRepository assurent déjà
la libération du chat avant déchargement. Les réutiliser.
ChatModelRepository ne conserve qu'un fichier personnalisé : ajouter un registre
Living Memory distinct et des copies privées immuables des modèles enregistrés.
Aucune modification du schéma SQLite 4 ou de l'espace de vecteurs 768.
Les tests V1.1 utilisent SQLite réel, des vecteurs synthétiques et des doubles
de conversation : aucune preuve matérielle S22.
Le certificat debug change entre runners : ne pas désinstaller une application
contenant des données pour forcer une installation. Pas de sauvegarde existante.

## Unités et ordre
1. Test rouge : extraction E4B avec le nom de fichier importé ; workflow V1.2.
2. multi_model_engine.dart : port de modèle local, requête, règles de routage,
   sélection manuelle, exclusivité couvrant chargement et inférence,
   fermeture avant chargement, repli unique E4B vers E2B, annulation sans repli,
   refus du repli si libération native impossible.
3. model_registry.dart : manifeste versionné indépendant et strict, écrit par
   remplacement atomique ; copies en flux, hash SHA-256, chemins privés.
   Aucun téléchargement ou modèle payant, aucune suppression de fichiers V1.1.
4. litert_memory_runtime.dart : adaptation aux services existants, mêmes contrôles
   de fichiers/backend, contexte conservateur 2048, aucun nouvel exécuteur natif.
5. model_panel.dart et MemoryScreen : enregistrer le modèle déjà importé depuis
   l'écran Modèles, modes Auto/E2B/E4B, état, erreurs et repli visibles.
   Sans registre, fonctionnement V1.1 conservé. Provenance dynamique du modèle.
6. Tests unitaires/widget : routage, exclusivité, ordre de libération, échecs,
   annulation, registre sur fichiers réels, redémarrage et rejet de corruption ;
   réexécuter toute la suite, analyse et format via Actions.
7. APK arm64, contrôle signature/hash/modèle embarqué, rapport et protocole S22.

## Limites assumées
Règles heuristiques, pas de mesure de complexité par un autre LLM.
Un seul modèle génératif résident, EmbeddingGemma reste indépendant.
Les copies privées consomment de l'espace disque ; aucun nettoyage automatique.
Le repli traite les erreurs récupérables Dart, pas une mort du processus Android
ni un crash natif. RAM libre/chauffe et compatibilité GPU restent à mesurer.
Ports futurs ToolRegistry/AgentRuntime/Scheduler déjà présents : pas d'outils
exécutés automatiquement, de service d'arrière-plan ou de bibliothèques chargées.
Sources : https://developers.google.com/edge/litert-lm/models/gemma-4
et https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm .
