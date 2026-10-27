# Audit technique — Living Memory

## Périmètre et provenance
Inspection du commit initial 659a03c49af38e45d235c1c7fdeb504b82fbb4ea,
du lock Flutter, des scripts de préparation, des moteurs RAG, des imports,
du manifest Android et des résultats Actions. Ce rapport n'est pas une
certification de sécurité exhaustive de chaque dépendance transitive.

Le dépôt est un fork de l'ensemble d'exemples Google AI Edge, et non une
copie de l'application native Google AI Edge Gallery. L'application concernée
est `samples/litert/flutter`. Les packages Flutter sont communautaires.

| Élément vérifié | Version / comportement conservé |
|---|---|
| Flutter / Dart | 3.47.3 / 3.13.3, `.fvmrc` et contrainte du projet |
| flutter_edge_ai | 2.5.1 selon pubspec.lock |
| flutter_edge_ai_litertlm | 1.17.0 selon lock |
| Runtime du package | native-v0.18.0-g, archives vérifiées SHA-256 par hook/build.dart |
| flutter_litert | 3.9.3, copie locale patchée via tool/flutter_litert/vendor.sh |
| flutter_edge_ai_rag / sqlite | 1.1.2 / 2.1.1 |
| sqlite3 | 3.7.1 déjà transitif, rendu direct pour la base privée |
| Bouncy Castle transitif | 1.72 demandé par PDFBox ; contraintes vers 1.86 (modules bcprov, bcpkix, bcutil) |
| PDFBox Android ajouté | com.tom-roush:pdfbox-android:2.0.27.0, Apache-2.0 |
| Android | API 30 minimum, arm64-v8a, Java 17 |

## Défauts constatés avant modification
- `.github/workflows/build-apk.yml` ne contenait qu'un saut de ligne :
  exécution sans job, échec antérieur 40429942034.
- Le build doit partir de `samples/litert/flutter`, préparer le plugin
  vendored puis télécharger les modèles publics du lock. Un simple pub get
  à la racine ou sans plugin/assets ne suffit pas.
- Le sélecteur Flutter d'origine refusait l'import Android, car son plugin
  charge les fichiers en un byte[]. Correction : SAF natif et copie en flux.
- La suite d'origine exécutée dans Actions a révélé deux défauts de tests :
  chemin LICENSE relatif erroné ; plateforme hôte Linux interrogée dans un
  test fakeAsync supposant un faux périphérique. Voir NON_REGRESSION.md.

## Compatibilité des modèles
- Génération : `.litertlm` générique `gemma-4-E2B-it.litertlm`, ModelType.gemma4.
  `.task`, GGUF et safetensors ne sont pas interchangeables avec ce conteneur.
- Ne pas choisir la variante Qualcomm SM8750 pour le S22 : un build NPU est
  spécifique au chipset. Le modèle générique propose CPU/GPU ; le fonctionnement
  de chaque backend sur le téléphone doit être observé, jamais déduit du nom.
- EmbeddingGemma 2 : bundle 740M `.litertlm` déjà prévu, tokenizer intégré,
  484 622 336 octets ; SHA-256
  e7a8a2204b91e0f96e92960e84a09a89212e1633dcb7575a9bf3378b4df77f4c.
  Source figée : litert-community/embeddinggemma-2-740m-litert-lm,
  commit 24d962e906c7d332c6428e71c9676855024569e2.
- 768 dimensions et limite de 1024 tokens contrôlées par EmbedderService.
  Les documents et requêtes passent respectivement par TaskType.retrievalDocument
  et TaskType.retrievalQuery. Le profil conserve les préfixes réels du package
  verrouillé : requête `task: search result | query: ` et document
  `title: none | text: `. Ces chaînes correspondent à la configuration
  SentenceTransformers publiée par Google pour EmbeddingGemma 2. La page
  LiteRT-LM donne d'autres chaînes : cette divergence documentaire est
  signalée, pas résolue par un changement arbitraire d'espace vectoriel.
  Le profil ne doit pas être réutilisé si modèle ou préfixes changent.
- Aucune extraction des fichiers privés de Gallery n'est tentée. Le fichier
  de génération doit être téléchargé ou choisi explicitement dans Android.

## Confidentialité et dépendances
- Le nouvel écran n'a ni client HTTP ni outil agentique. Sa conversation est
  recréée pour chaque question. Aucun document privé ne sert au build CI.
- La permission INTERNET historique reste nécessaire aux téléchargements
  optionnels de modèles et à la démo caméra réseau. Elle ne prouve pas une
  transmission de documents ; le fonctionnement hors ligne doit être essayé.
- SQLite est dans le support privé de l'application, sans chiffrement ajouté.
  Sauvegarde cloud et transfert automatique des données désactivés par manifest
  et règles Android 12+. Désinstaller ou effacer les données détruit la mémoire.
- TXT strict UTF-8 ; PDF texte via PDFBox. 16 Mio maximum, 200 pages, pas d'OCR.
  Les fichiers malformés peuvent encore demander des ressources au parseur ;
  aucun fuzzing ni test de tous les formats PDF n'a été exécuté.
- Les modèles fournis restent vérifiés par taille/SHA-256. L'import du modèle
  utilisateur conserve les validations du store et du moteur existants.
- Les modèles caméra/voix existants restent embarqués pour préserver les démos :
  cela augmente l'APK. YOLO26n garde sa licence AGPL-3.0 et ses notices/sources.
  Les licences originales et leurs tests ne sont pas retirés.
- Aucun fournisseur IA payant ajouté, aucun compte cloud IA nécessaire.

## Sources primaires consultées
- https://developers.google.com/edge/litert-lm/models/gemma-4
- https://developers.google.com/edge/litert-lm/embedding_models
- https://github.com/TomRoush/PdfBox-Android
- https://pub.dev/packages/sqlite3/versions/3.7.1
- Le code, lock, hook/build.dart et tool/models.lock réellement inspectés.

PDFBox demande Bouncy Castle 1.72 dans son POM. Les trois modules sont contraints
à 1.86, version de durcissement officielle vérifiée sur Maven Central. Le rapport
Gradle de l'artefact doit confirmer la résolution réelle ; cela ne constitue
pas une garantie d'absence de vulnérabilités dans toute l'application.
Sources complémentaires :
- https://www.bouncycastle.org/resources/new-release-bouncy-castle-java-1-86/
- https://huggingface.co/google/embeddinggemma-2/blob/main/config_sentence_transformers.json
