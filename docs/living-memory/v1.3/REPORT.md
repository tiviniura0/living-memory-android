# Living Memory V1.3 — rapport de validation

## Livrables et provenance

Version : **1.3.0+4**, ARM64, application expérimentale.
Branche : `work/living-memory-v1.3-google-integration`.
Commit applicatif : `cadef86749ea1fe0625f86b0ab1234c12115cff3`.

- [Run ayant produit l’APK](https://github.com/tiviniura0/living-memory-android/actions/runs/40638529913) — terminé avec succès (validation logicielle et APK).
- [Archive exacte contenant app-release.apk](https://github.com/tiviniura0/living-memory-android/actions/runs/40638529913/artifacts/12795435247).
- [Preuves légères : journaux, manifeste, dépendances, signature](https://github.com/tiviniura0/living-memory-android/actions/runs/40638529913/artifacts/12794922655).
- SHA-256 APK : `a6fbffa52ac9b82ee334800695d3439ae6e0f8d2811ef5a62bdf6f2911c7e555`.
- Taille APK : 898044628 octets ; ABI contrôlée : `arm64-v8a`.
- Empreinte SHA-256 du certificat : `2793f7eebc12659fa12fa44c4f0521bdcfdc74915235023b1591df57dd816972`.
- Conservation GitHub de l’archive APK : 10/11/2026 à 19:46 (Tahiti). Le lien vise un ZIP à extraire, pas un APK hébergé en URL brute.

Référence suivie : `docs/living-memory-google-integration-correction.md`.
La baseline a été reconstruite avant l’intégration : [run 40633319051](https://github.com/tiviniura0/living-memory-android/actions/runs/40633319051), 3 014 tests réussis et 15 ignorés ; APK et métadonnées conservés (BASELINE.json).
Aucune fusion stable. Les références `main` et V1.2 ont été contrôlées inchangées :
`0f95b7eb0db759ed4a0071756c231c94e36f6c04` et `376ccf33353ec101b1c424b6121eb69ecfc55f62`.

## Ce qui a changé

Les services Google sont réutilisés : aucun nouveau moteur d’inférence, de voix,
d’images ou de base vectorielle. L’écran Living Memory propose discussion,
rédaction, image choisie explicitement, dictée française, import WAV et lecture.
Les productions peuvent être conservées comme sources sur action explicite.
Les conversations sont enregistrées dans l’historique local de l’agent/projet.
Les descriptions/transcriptions sont marquées non vérifiées ; les originaux
image/audio ne sont pas archivés par Living Memory.

Une conversation native neuve reçoit un historique borné du scope courant.
Les tests vérifient le changement d’agent et la frontière de réinitialisation,
y compris après compaction. Le RAG strict V1.2 reste disponible séparément.

SQLite et son schéma 4 sont conservés. `pubspec.lock`, le profil EmbeddingGemma 2
768 dimensions, ReliabilityEngine, AutoMemoryEngine, ContextLifecycleManager et
MultiModelEngine sont inchangés par rapport à la base. Les nouveaux contrats
ChatProvider, ImageAnalysisProvider, SpeechToTextProvider, TextToSpeechProvider,
MemoryRepository et ModelManager exposent les composants existants.
L’interface Living World AI est préservée ; aucune intégration réelle avec
Living World AI ni API authentifiée n’a été testée.

Le registre permet maintenant la suppression de copie privée, la réserve
d’espace, l’arrêt de copie et le remplacement après écriture atomique du
manifeste. Les liens symboliques sont refusés. Les sources originales sont
conservées. Le choix Auto/E2B/E4B et les gardes de libération native restent ceux
de V1.2.

## Preuves de tests

Résultat final : **3038 tests réussis, 15 ignorés**, aucun
échec ; **129 tests ciblés réussis**. Analyse et formatage : réussis.
Contrôles Python : signature, confidentialité Android et versions natives : réussis.
Les tests ignorés et leurs conditions sont détaillés dans le journal complet.

| Fonction | Preuve réellement exécutée | Limite |
|---|---|---|
| Chat/rédaction et continuité | Tests AssistantSession et widget UI→SQLite réel, deux agents, sortie avec événement terminal non interrompu, sauvegarde explicite, reset/compaction | Génération simulée ; aucune qualité de réponse réelle mesurée |
| RAG et données | Suite mémoire existante : SQLite réel, migrations, agents/projets, déduplication, citations et abstention | Vecteurs synthétiques ; pas de vérification logique/externe des faits |
| Image | Sélection/normalisation Google couverte par la suite ; octets PNG transmis à l’adaptateur, provenance hashée, modèle sans vision refusé | Sélecteur Android et inférence visuelle réelle non exécutés |
| Dictée/lecture | Services vocaux Google avec doubles STT/TTS/audio ; français transmis par appel ; refus micro, annulation pendant STT, focus perdu, sortie retirée | Pas de microphone/haut-parleur réel ni validation de prononciation française |
| WAV | Octets synthétiques réellement décodés ; taille, durée, format et limites de blocs ; fichier tronqué refusé avant activation du modèle | SAF Android réel non exécuté ; PCM16 mono 16 kHz, 30 s maximum, pas de MP3/M4A |
| Gestionnaire de modèles | Fichiers temporaires réels, empreintes, altération, persistance, remplacement, suppression confinée, faible espace et annulation ; tests téléchargement/import existants | Petits fichiers de test ; pas de transfert multi-Go sur S22 |
| Android et APK | Manifeste fusionné, absence de permissions de stockage étendues, sauvegardes exclues, non-débogable, politique HTTP, dépendances résolues, signature, ABI, SHA-256 du modèle embarqué | Compilation et inspection, pas une installation sur téléphone |

Deux revues indépendantes ont été réalisées. Les régressions audio ont été
observées rouges avant correction (40635699791), ainsi que le rappel d’archives
après reset (40636987109). Le plan et AUDIT.md conservent les résultats et
les décisions. La suite complète finale couvre les corrections.

## Sécurité et dépendances

Le badging baseline révélait READ/WRITE_EXTERNAL_STORAGE transitives : elles
sont retirées du manifeste fusionné final. Les composants exportés autres que
le launcher doivent être protégés par une permission système de diagnostic ou
par BIND_JOB_SERVICE pour les services WorkManager/UIDT attendus. HTTP non chiffré est
explicitement désactivé par la politique Android ; les parcours réseau de démo
avec URL HTTP doivent être vérifiés et privilégier HTTPS.

L’audit OSV a interrogé 148 versions Pub et 147 coordonnées/version Maven de la
baseline. Deux dépendances natives concernées ont été corrigées : Guava vers
33.7.2-android et OkHttp vers 4.9.2. Le graphe final résout Guava 33.7.2-android et OkHttp 4.9.2.
Le nouveau contrôle OSV du graphe Maven final : aucun avis retourné pour les 147 coordonnées/version résolues interrogées. Les
réponses brutes sont conservées dans les fichiers DEPENDENCIES*.json.
Ce contrôle ne certifie pas tous les binaires natifs distribués par les SDK.

Sources : [avis Guava](https://github.com/google/guava/security/advisories/GHSA-xxph-c9ww-hj94),
[version corrective Guava](https://github.com/google/guava/releases/tag/v33.7.2),
[avis OkHttp](https://github.com/advisories/GHSA-3cqm-mf7h-prrj),
[API OSV](https://api.osv.dev/v1/querybatch).
Les licences et notices existantes sont conservées, dont YOLO AGPL-3.0 et les
conditions des modèles Gemma ; la redistribution commerciale n’est pas certifiée.

## Limites et installation

**Aucun test sur Galaxy S22 Ultra n’a été exécuté.** Ni E2B/E4B réel, ni RAM,
chauffe, latence, mode avion, permissions ou stabilité native n’ont été mesurés.
Un arrêt Android ou crash natif ne peut pas être rattrapé par le repli Dart.

La copie SAF initiale d’un modèle vers le cache Android n’est pas interrompable
par Dart ; l’arrêt du téléchargement et de la copie du registre est distinct.
L’intégrité calculée seule n’authentifie pas un éditeur sans hash de confiance.
Les redirections CDN HTTPS restent autorisées, sans liste blanche d’hôtes.

Les productions libres sont des brouillons, pas des faits certifiés. Le rappel
conversationnel conserve au plus six textes récents de 1 200 caractères Unicode
chacun, puis s’adapte au budget du modèle. Une instruction dépassant la limite
d’embedding peut être traitée sans recherche vectorielle. L’analyse des médias
est mémorisée sous forme de texte dérivé ; pas d’OCR de PDF scanné ni d’archive
multimédia brute. La sortie est bornée au budget existant du générateur.

Supprimer une source n’efface pas les anciennes réponses copiées dans les
sessions/checkpoints. Un reset du contexte actif préserve les archives,
documents et décisions permanentes. Le stockage privé n’est pas chiffré par
l’application ; les logs historiques peuvent contenir des transcriptions.

**Ne pas désinstaller une version contenant des données pour contourner une
signature différente.** Le build utilise une clé debug Actions non pérenne.
La mise à jour nécessite le même certificat ; aucun export/restauration complet
n’est disponible. Utiliser une installation vierge ou une signature compatible.

Les instructions détaillées, commandes ADB et la grille de validation sont dans
[INSTALL_S22.md](INSTALL_S22.md). Les cases matérielles restent « non exécuté ».
Aucune fusion vers une branche stable n’a été réalisée ou autorisée ici.

Le lancement local de Flutter a été rejeté par le contrôle automatique pour une
requête inattendue vers les métadonnées cloud 169.254.169.254. Les tests et builds
ont été effectués dans GitHub Actions, sans contourner ce blocage local.
