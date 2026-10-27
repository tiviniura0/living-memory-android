# Living Memory — conception V1

Mission autorisée : étendre le fork existant sans supprimer les démos ni les tests.
Source inspectée : 659a03c49af38e45d235c1c7fdeb504b82fbb4ea.

## Décision
Conserver Flutter 3.47.3 / Dart 3.13.3 et les moteurs existants
flutter_edge_ai_litertlm 1.17.x. Ajouter un écran indépendant accessible
à l'accueil, utilisant le même embedder et la même conversation, sans outils
agentiques ni appel réseau. Une conversation neuve par question empêche
la fuite du contexte d'un agent vers un autre.

Alternatives : remplacer l'application par Kotlin réduirait les dépendances
mais perdrait le travail et les tests ; modifier l'index documentaire livré
mélangerait sources techniques publiques et documents privés. Les deux sont
écartées. Un module séparé dans l'application préserve les comportements.

## Données locales
SQLite privé, distinct de kb.db ; agents, documents et passages, filtre
agent_id obligatoire avant classement cosinus. Profil d'embedding inscrit
et vérifié à l'ouverture ; aucune destruction automatique en cas de désaccord.
Vecteurs réels issus de l'embedder existant. Import atomique après tous les
embeddings ; un échec ne laisse pas de document partiellement indexé.
SHA-256 pour dédoublonner par agent. Suppression limitée à l'agent courant.
Passages courts bornés en octets UTF-8 pour respecter la limite du modèle.
Citations : fichier, page PDF / numéro de passage, texte consultable et score.
Les citations prouvent la provenance du passage, pas la vérité de la génération.

## Android sans ordinateur
Sélecteur système ACTION_OPEN_DOCUMENT, lecture locale uniquement.
TXT UTF-8 et PDF contenant du texte ; pas d'OCR. PDFBox Android Apache-2.0,
16 Mio / 200 pages maximum, erreurs explicites pour chiffré, vide ou trop long.
Modèles de plusieurs Go copiés en flux vers cache privé, sans byte[] global,
puis importés par le mécanisme existant. Pas d'accès aux fichiers internes
privés de Google AI Edge Gallery. Configuration par sélection d'un fichier
.litertlm exporté/téléchargé, ou téléchargement officiel existant.

## Modèles
Gemma 4 E2B .litertlm générique CPU/GPU ; aucune promesse de NPU S22.
EmbeddingGemma 2 740M .litertlm déjà fourni au build, tokenizer embarqué,
768 dimensions, plafond de 1024 tokens vérifié par l'application existante.
Aucun achat ni API IA. La configuration et les téléchargements publics peuvent
nécessiter Internet ; import, indexation, recherche et réponse sont locaux.

## Mémoire Living World AI
Une identité persistante par agent (id stable et nom). Les notes manuelles
sont des documents de type note ; un futur orchestrateur pourra ajouter des
observations et réflexions à cette même frontière d'import, en conservant
source, date et agent. Pas de monde autonome exécuté dans cette V1.

## Vérification
Suite existante avant/après, nouveaux tests SQLite (persistance, isolation,
dédoublonnage, rollback, profil, vecteurs invalides), découpage UTF-8,
classement et abstention. Tests Android d'import et inférence réelle sur S22
à distinguer des tests Dart et de la compilation. Workflow Actions épinglé,
artefact APK arm64 et empreinte SHA-256. Signature debug documentée.
