# Signature stable et conservation des données

Aucune clé privée de production n'est générée par cette mission. La clé AES
créée dans Android Keystore sur l'appareil est distincte de la clé de signature APK.

## Installation existante

L'identifiant reste `com.google.ai.edge.examples.litert_edge_demos`. Avant une
mise à jour, relever le certificat de l'APK installé (`adb shell pm path`,
`adb pull` de base.apk puis `apksigner verify --print-certs`). Comparer au
certificat du candidat. Si le certificat diffère, ARRÊTER : ne pas désinstaller,
ne pas effacer les données, ne pas changer l'identifiant pour prétendre les
avoir migrées. Retrouver la clé originale et reconstruire. La clé debug du run
V1.3 n'est pas présumée récupérable. Une nouvelle clé stable ne peut pas à elle
seule signer une mise à jour acceptée de cette installation.

## Provisionnement stable (par le propriétaire)

1. Choisir un coffre hors GitHub et hors dépôt, avec sauvegarde chiffrée sur
   deux supports indépendants, accès restreint, mots de passe dans un gestionnaire
   séparé et une procédure documentée de restauration/test.
2. Rechercher et conserver d'abord toute clé ayant signé une installation avec
   des données. Si aucune identité existante ne doit être conservée, créer la
   nouvelle clé uniquement sur le poste sécurisé du propriétaire, dans ce coffre.
   Ne jamais transmettre clé/mots de passe dans un prompt, log, issue ou commit.
3. Enregistrer alias, certificat public/SHA-256 et responsable. Vérifier la
   restauration depuis la sauvegarde sur un poste autorisé avant distribution.
4. Sur ce poste, fournir `android/key.properties` (ignoré par Git) et un
   `storeFile` absolu hors dépôt ; accès fichier limité au propriétaire. Les
   champs attendus sont storeFile, storePassword, keyAlias, keyPassword. Ne
   publier aucun exemple avec des secrets réels.
5. Construire sans opt-in expérimental, vérifier `apksigner verify --verbose
   --print-certs`, le SHA-256, l'ABI et le manifeste. Comparer impérativement le
   certificat installé. Installer avec `adb install -r` seulement si compatible.
6. Avant toute généralisation, vérifier redémarrage, ouverture de l'enveloppe
   Keystore, migration et conservation des agents/sessions/documents sur S22.

La CI publique n'a pas cette clé. Un APK debug expérimental peut être produit
avec un opt-in explicite ; son certificat n'est pas stable et l'artefact n'est
pas une mise à jour garantie. Ne pas stocker le keystore dans GitHub, y compris
en base64 dans le workflow, dans les artefacts, dans le cache ou dans les logs.
Aucun export/restauration complet n'est encore proposé par l'application.
