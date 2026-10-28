# Audit V1.3 — intégration sur la base Google conservée

Référence : `docs/living-memory-google-integration-correction.md`.
Base de code : `f8f87666` (runtime `376ccf33`). Audit de l’application Flutter,
de ses services Android et de son pipeline ; les autres démonstrations du
monorepo ne deviennent pas des fonctionnalités Living Memory par leur présence.
Aucun téléphone connecté ; toutes les lignes « appareil » restent non exécutées.

## Cartographie et réutilisation

| Fonction | Code existant réutilisé | Tests logiciels existants | Appareil |
|---|---|---|---|
| Chat texte, budget et arrêt | data/repositories/conversation_repository_edge_ai.dart ; domain/use_cases/chat_turn_responder.dart | test/data/repositories/conversation* ; test/domain/use_cases/chat_turn_responder* | non exécuté |
| Image et normalisation PNG | data/repositories/image_repository.dart ; data/services/images/ | test/data/repositories/image_repository_test.dart ; tests normalisation | non exécuté |
| Capture et focus audio | data/repositories/audio_repository_device.dart ; data/services/audio/ | test/data/repositories/audio* ; test/domain/use_cases/voice_assistant* | non exécuté |
| Whisper et TTS Inflect | data/repositories/speech_repository.dart ; data/services/speech/ | test/data/repositories/speech_repository_test.dart ; tests STT/TTS | non exécuté |
| SQLite et import texte/PDF | living_memory/memory_store.dart ; android/.../LivingMemoryDocuments.kt | test/living_memory/memory_store_test.dart ; migrations | SAF/PDF Android non exécuté ici |
| EmbeddingGemma 2, 768 dimensions | config/knowledge_config.dart ; data/services/knowledge/embedder_service.dart | tests profil/vecteurs, KB ; poids vérifiés dans APK par CI | inférence réelle non exécutée |
| Agents/projets et mémoire fiable | living_memory/reliability_engine.dart ; context_lifecycle_manager.dart | test/living_memory/reliability* ; session_retrieval* ; context* | non exécuté |
| E2B/E4B séquentiels | living_memory/multimodel/ | registre réel en fichiers temporaires, runtime natif simulé, fermeture refusée | GPU/NPU, E4B et OOM non exécutés |
| Import/téléchargement modèle | data/services/model_store/ ; chat_model_repository.dart | import, checksum, annulation, redirection et disque simulé ; fichiers réels temporaires | modèle multi-Go sur S22 non exécuté |

Les suites existantes incluent de nombreux doubles de test : elles ne mesurent
ni la qualité d’une réponse, ni la RAM native. Les tests `integration_test/`
qui requièrent matériel/poids ne sont pas lancés par `flutter test`.

## Modifications V1.3

- `AssistantSession` : adaptateur ChatProvider/ImageAnalysisProvider sur
  ConversationRepository. Nouvelle conversation native sans outils pour chaque
  opération, alimentée par l’historique borné du scope courant ; sorties vides, interrompues ou sans terminal rejetées. Scope
  attaché à la sortie ; descriptions visuelles dérivées avec empreinte PNG.
- Route mémoire : discussion/rédaction, passages de l’agent/projet courant,
  image choisie explicitement, dictée et lecture par services existants.
  Le RAG strict avec validation des citations V1.2 est conservé séparément.
- Productions libres : marquées non vérifiées. Enregistrement comme source
  uniquement sur action explicite ; pas d’extraction Auto-Memory automatique
  de ces productions. Les textes de conversations restent dans l’historique
  local de la portée. Il n’y a pas de migration destructive de la base.
- Registre : suppression explicite de copie privée, contrôle du type de fichier
  et refus des liens symboliques, réserve d’espace, annulation de copie.
  La copie remplacée n’est retirée qu’après écriture atomique du manifeste.
- STT : paramètre français par appel, sans changer les réglages anglais des
  démonstrations historiques. La qualité française et la voix TTS ne sont pas
  validées sur appareil.

## Revue indépendante et décisions

Revue en lecture seule de la baseline par un autre agent :
1. Copies de modèles sans limite : correction ciblée du registre, réserve
   d’espace, remplacement après commit et suppression explicite.
2. Suppression d’une source : ne supprime pas les copies de réponses dans les
   historiques/checkpoints. L’UI l’indique ; aucune promesse d’effacement global.
   Aucun nouvel effacement automatique de sessions existantes.
3. Pas de liste blanche d’hôtes : le téléchargement personnalisé est une action
   explicite sur une URL HTTPS fournie par l’utilisateur. Les redirections vers
   d’autres CDN HTTPS restent permises, l’abaissement HTTPS→HTTP est refusé.
   Ce mécanisme n’authentifie pas l’éditeur des poids ; SHA-256 sans empreinte
   de confiance démontre seulement la stabilité des octets.

## Sécurité et dépendances

- `allowBackup=false`, règles cloud/device-transfer d’exclusion, base privée,
  `secure_delete`, requêtes paramétrées et schéma/profil futur refusé sans reset.
- Launcher exporté nécessaire ; aucun service de mémoire exporté. SAF système,
  pas de permissions de stockage étendues. Micro/photo demandés à l’action.
- Trafic non chiffré explicitement désactivé ; pas de client cloud dans les
  nouveaux adaptateurs. Les modèles et les sources distantes de caméra sont
  des parcours réseau distincts de l’inférence locale.
- Dépendances Dart verrouillées, plugin flutter_litert épinglé avec patch
  conservé, hashes des modèles publics conservés. Pas de mise à jour globale.
- `DEPENDENCIES.json` contient requêtes/réponses OSV : 152 versions interrogées,
  aucun avis retourné au moment de la requête. Couverture partielle des
  dépendances natives ; absence d’avis ne prouve pas absence de vulnérabilité.
- Licences déjà présentes : Apache-2.0, MIT, BSD pour divers composants ;
  YOLO26n AGPL-3.0, poids Gemma sous conditions propres. Conserver notices et
  vérifier les obligations avant redistribution commerciale. Aucun avis
  juridique ni certification de conformité fourni.
- Stockage non chiffré par l’application. Android constitue la frontière de
  sécurité ; MemoryScope est un espace de noms, pas une authentification.
- Les logs historiques des démos peuvent contenir des transcriptions et chemins.
  Aucun dump de prompt/production ajouté par les adaptateurs V1.3. Ne pas utiliser
  des données personnelles dans les journaux de validation partagés.

## Limites de validation

Le runtime local Flutter a été bloqué par l’approbation automatique pour une
requête inattendue vers les métadonnées cloud 169.254.169.254. Pas de contournement :
exécution des tests/builds via GitHub Actions. Le formatteur Dart autonome et les
contrôles Python locaux restent utilisables. Graphify n’était pas installé ;
cartographie par recherche/lecture du code, aucun graphe synthétique revendiqué.

Aucune mesure S22 de RAM, chauffe, latence, batterie, fonctionnement en avion,
permission réelle, modèle E4B ou stabilité native. Une erreur Dart permet un repli ;
un crash natif ou un arrêt Android ne peut pas être rattrapé par ce code.

## Complément de l’audit natif

147 coordonnées/version Maven du graphe Gradle baseline ont été interrogées.
Deux avis sont revenus : Guava 33.5.0-android (GHSA-xxph-c9ww-hj94) et OkHttp
4.9.0 (GHSA-3cqm-mf7h-prrj). Les contraintes ciblées passent à 33.7.2-android
et 4.9.2. Le gate CI contrôle les versions **résolues** après compilation ;
les versions demandées dans une branche du graphe ne suffisent pas.
Les requêtes/réponses initiales sont conservées dans DEPENDENCIES_NATIVE_BASELINE.json.

Sources primaires :
- https://github.com/google/guava/security/advisories/GHSA-xxph-c9ww-hj94
- https://github.com/google/guava/releases/tag/v33.7.2
- https://github.com/advisories/GHSA-3cqm-mf7h-prrj
- https://api.osv.dev/v1/querybatch

La présence d’une version concernée n’est pas la preuve d’une exploitation
possible dans cette application. L’objectif est de retirer ces versions connues,
puis de vérifier le graphe et le build, sans mise à jour générale des plugins.

## Revue de l’intégration et corrections vérifiables

Une seconde revue indépendante en lecture seule a identifié deux défauts,
reproduits avant correction dans le run 40635699791 : absence d’écoute des
interruptions audio (deux dictées bloquées et TTS non annulée), et acceptation
d’un bloc WAV annonçant plus de données que le fichier. Les adaptateurs écoutent
maintenant les interruptions pendant capture/lecture et attendent l’arrêt de la
session audio ; les fichiers WAV importés ont une validation stricte des blocs.
Le décodeur Google partagé reste inchangé pour les parcours historiques.

Continuité du chat : les six derniers messages de la session courante sont
proposés au modèle (chaque texte borné à 1 200 caractères Unicode). Les
checkpoints de compaction/reset sont respectés ; les plus anciens éléments et
les passages sont retirés si le budget de contexte l’exige. Ce contexte est
présenté comme donnée non fiable, jamais comme preuve de vérification.
Les modèles continuent de s’ouvrir sans historique natif partagé entre agents.

Tests matériels non exécutés : tous les résultats logiciels gardent les doubles
de l’inférence, des entrées/sorties audio et des événements du système.
