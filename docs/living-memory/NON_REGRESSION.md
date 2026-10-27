# Rapport de non-régression — Living Memory Android

Date utilisateur : 26 octobre 2026 (Tahiti). Les horodatages Actions sont en UTC.
Original : 659a03c49af38e45d235c1c7fdeb504b82fbb4ea.
Dépôt : https://github.com/tiviniura0/living-memory-android
Branche de travail : work/living-memory-local-rag.

## Résultat final vérifié

| Exécution Actions | Révision | Résultat constaté |
|---|---|---|
| 40429942034 | 659a03c | Workflow APK vide ; échec avant création d'un job |
| 40431295274 | a784713 | Préparation et analyse OK ; 2929 tests réussis, 15 ignorés, 2 échoués ; pas d'APK |
| 40432164417 | 2159578 | Analyse arrêtée sur 13 règles de style ; tests/build non exécutés |
| 40432584772 | 7a55565 | Analyse sans problème ; 2943 tests réussis, 15 ignorés ; build annulé par la nouvelle révision |
| 40433141661 | 451da92 | Analyse OK, 2943 réussis / 15 ignorés ; échec R8 sur JP2Decoder optionnel absent |
| 40434835372 | 2ebcad7 | Succès : analyse sans problème, 2943 réussis / 15 ignorés, APK compilé et artefact publié |
| 40437013088 | b0e6d0c | Succès : hash APK conforme, ABI arm64, modèle embarqué, signature v2 et dépendances vérifiés |

Preuves principales :
- https://github.com/tiviniura0/living-memory-android/actions/runs/40434835372
- https://github.com/tiviniura0/living-memory-android/actions/runs/40437013088
La ligne exacte de preuve pour 7a55565 est :
`2026-10-27T01:31:37.3261812Z 02:20 +2943 ~15: All tests passed!`.
Un build annulé n'est pas présenté comme une compilation réussie.

## Corrections des deux tests d'origine
1. `test/config/licenses_test.dart` : le fichier LICENSE est à la racine du
   dépôt (`../../../LICENSE` depuis le projet Flutter), pas dans le dossier
   courant. Toutes les assertions sur le texte Apache-2.0 sont conservées.
2. `test/data/repositories/audio_repository_test.dart` : le test de drain
   à horloge simulée construisait son dépôt sans plateforme explicite,
   contrairement au helper voisin. Il lançait donc une vérification Linux
   du runner. L'injection HostPlatform.macos aligne ce test sur son helper ;
   les assertions de temporisation et d'arrêt audio sont inchangées.

## Nouveaux tests
Douze tests ajoutés : huit de stockage et quatre de découpage.
Ils utilisent une véritable base SQLite temporaire et des vecteurs synthétiques
explicites pour tester les algorithmes, pas des embeddings prétendument générés.
- Filtrage par agent avant classement, même avec des vecteurs identiques.
- Classement cosinus et absence de résultat sous le seuil.
- Refus des vecteurs nuls, NaN, infinis, mauvaise dimension et norme nulle.
- Déduplication propre à chaque agent.
- Rollback d'une insertion qui échoue au milieu, puis réutilisation de la base.
- Suppression qui ne traverse pas la frontière d'un autre agent.
- Persistance et refus d'un autre profil sans effacement des données.
- Rejet d'identifiants de type chemin / texte SQL.
- UTF-8 multioctet préservé sous 700 octets par passage.
- Conservation des pages PDF, y compris les pages vides.
- Refus de documents vides et de corpus dépassant 10 000 passages.

## Préservation
Le workflow, les ajouts natifs et l'écran de mémoire étendent le projet existant.
Les démos, modèles livrés, corpus technique kb.db, scripts et tests existants
ne sont pas supprimés. Le nouveau stockage `living-memory-v1.db` est distinct.
Les 4269 fichiers suivis à l'origine restent présents : vérification git ls-tree
et diff --diff-filter=D sans suppression. Deux tests existants ont été corrigés
comme expliqué ci-dessus.
Aucune migration ou destruction automatique d'une ancienne base privée.

## Tests non exécutés et limites matérielles
- Installation de l'APK sur le Galaxy S22 Ultra, sélecteur de fichiers Android
  réel, copie d'un modèle de plusieurs Go, extraction PDF sur cet appareil.
- Génération Gemma et embeddings réels sur S22, qualité de recherche en français,
  latence, RAM, chauffe, batterie, compatibilité GPU/CPU/NPU.
- Vérification mode avion après redémarrage, tests instrumentés Android et UI
  du nouvel écran sur appareil. Les tests Flutter existants restent exécutés.
- Les 15 tests ignorés sur le runner Linux : 7 dépendent de macOS/iOS
  (matériel macOS, chflags uchg, clone APFS), 7 de TurboJPEG disponible
  (6 décodeur + 1 caméra réseau), 1 de l'option de captures de mise en page.
  Les conditions viennent des tests d'origine et restent inchangées.
  Aucun de ces tests n'est compté comme un succès.
- PDF scannés/OCR, documents chiffrés, multi-utilisateur sécurisé, chiffrement
  applicatif et export/restauration ne sont pas implémentés.
- Seuil cosinus réglable, non calibré sur les documents personnels. Les sources
  affichées désignent des passages retrouvés ; une citation ne garantit pas
  l'exactitude d'une phrase générée.

## Environnement de travail
Une commande Flutter locale a été rejetée par le contrôle automatique car
elle tentait d'accéder à un endpoint de métadonnées de l'environnement cloud.
Elle n'a pas été contournée : analyse/tests/compilation sont réalisés via
GitHub Actions. Formatage Dart et vérification syntaxique des XML effectués
localement ; ce ne sont pas des preuves d'inférence ni de compilation Android.

## Livraison
Version compilée : 2ebcad7ae79805019ed242555c0170d90484b8b2.
La dernière mise à jour ajoute seulement le workflow de contrôle et la
documentation ; elle ne modifie pas le code de l'application compilée.

- APK : app/outputs/flutter-apk/app-release.apk, dans l'archive.
- Taille exacte APK : 897782148 octets (897,8 Mo décimaux).
- SHA-256 APK : `947056320e43a88ab4f988f9d23cae462be9aefb103f27d707acf2386dc8b7e3`.
- ABI : arm64-v8a uniquement, vérifiée dans l'APK.
- Signature : apksigner vérifie le schéma v2 ; certificat Android Debug,
  RSA 2048 bits. Il s'agit d'un APK d'essai, sans clé de production permanente.
- SHA-256 certificat : `cc90f8b4d170d0410025bab5ba3af71567fd6ecbd420c411230043c7389dc487`.
- EmbeddingGemma 2 intégré : 484622336 octets, présence/taille contrôlées.
- Bouncy Castle bcprov/bcpkix/bcutil : résolution effective 1.86 vérifiée.
- ZIP : 660675153 octets ; SHA-256
  `6b20e80ad2f2c194f34d85806475cccf8994b6013a28fca94ac4866790bd2ab5`.
- [Archive APK](https://github.com/tiviniura0/living-memory-android/actions/runs/40434835372/artifacts/12704446999).
  Expiration annoncée par GitHub : 2026-11-10T02:05:12Z.
- [Preuves légères : logs tests, dépendances, manifest et signature](https://github.com/tiviniura0/living-memory-android/actions/runs/40437013088/artifacts/12704915701).

L'outil de transfert de fichiers de cette session refuse les artefacts
supérieurs à 536870912 octets. L'archive complète dépasse cette limite :
livraison par téléchargement GitHub, sans ordinateur personnel.
L'environnement local est ensuite devenu indisponible ; la vérification
finale de l'artefact a été réalisée dans Actions, avec succès.

## Cause du premier échec Android réel
Le compilateur Dart/Kotlin et les dépendances natives ont franchi leurs étapes.
R8 a refusé la classe optionnelle com.gemalto.jp2.JP2Decoder référencée par
PDFBox. Correction ciblée : proguard-rules.pro ne supprime que cet avertissement,
car l'application extrait du texte sans décoder d'image JPX ; le contrôle de
présence de classe est prévu par le code officiel de PDFBox. R8 reste activé.
La compilation 40434835372 a confirmé cette correction ; R8 est resté actif.

## Couverture de la mission

| Demande | Livraison / limite |
|---|---|
| Dépôt existant préservé | Historique conservé, aucun fichier original supprimé |
| Audit Flutter et dépendances | AUDIT.md, lock et versions natives inspectés ; pas de certification exhaustive de sécurité |
| Workflow défaillant | Fichier vide remplacé, chaîne de compilation prouvée par Actions |
| Gemma 4 / EmbeddingGemma 2 | Moteurs existants conservés et réutilisés ; formats .litertlm vérifiés ; pas d'inférence réelle sur S22 |
| RAG local TXT/PDF | Import local, SQLite distinct, passages et pages citables ; PDF texte sans OCR |
| Mémoire individuelle | Filtrage obligatoire par agent, notes persistantes ; architecture future documentée |
| APK Android via Actions | APK arm64 produit, hash/signature/structure vérifiés |
| Tests et non-régression | 2943 réussis, 15 ignorés, limites matérielles explicites |

Aucun fournisseur IA payant ajouté ni document privé inclus dans les builds.
Les réponses ne sont pas ajoutées automatiquement à la mémoire. L'utilisateur
reste responsable de vérifier les passages cités lors de l'essai sur téléphone.
