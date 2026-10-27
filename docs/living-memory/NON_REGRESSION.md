# Rapport de non-régression — Living Memory Android

Date utilisateur : 26 octobre 2026 (Tahiti). Les horodatages Actions sont en UTC.
Original : 659a03c49af38e45d235c1c7fdeb504b82fbb4ea.
Dépôt : https://github.com/tiviniura0/living-memory-android
Branche de travail : work/living-memory-local-rag.

## Preuves déjà obtenues

| Exécution Actions | Révision | Résultat constaté |
|---|---|---|
| 40429942034 | 659a03c | Workflow APK vide ; échec avant création d'un job |
| 40431295274 | a784713 | Préparation et analyse OK ; 2929 tests réussis, 15 ignorés, 2 échoués ; pas d'APK |
| 40432164417 | 2159578 | Analyse arrêtée sur 13 règles de style ; tests/build non exécutés |
| 40432584772 | 7a55565 | Analyse sans problème ; 2943 tests réussis, 15 ignorés ; build annulé par la nouvelle révision |
| 40433141661 | 451da92 | Analyse OK, 2943 réussis / 15 ignorés ; échec R8 sur JP2Decoder optionnel absent |

Les liens sont `https://github.com/tiviniura0/living-memory-android/actions/runs/ID`.
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
Deux tests existants ont été corrigés comme expliqué ci-dessus.
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
À compléter après la fin du build final : artefact, taille, SHA-256 et statut
réel. Ne pas considérer cette section provisoire comme une livraison d'APK.

## Cause du premier échec Android réel
Le compilateur Dart/Kotlin et les dépendances natives ont franchi leurs étapes.
R8 a refusé la classe optionnelle com.gemalto.jp2.JP2Decoder référencée par
PDFBox. Correction ciblée : proguard-rules.pro ne supprime que cet avertissement,
car l'application extrait du texte sans décoder d'image JPX ; le contrôle de
présence de classe est prévu par le code officiel de PDFBox. R8 reste activé.
Une nouvelle compilation doit confirmer cette correction.
