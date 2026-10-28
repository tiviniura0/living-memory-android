# Living Memory V1.3.1 — durcissement de sécurité

Statut : **validation logicielle et APK réussie**. Tests S22 Ultra : **non exécutés**.
Version : 1.3.1+5, ARM64 expérimental. Branche :
`work/living-memory-v1.3.1-security`, créée depuis
`b77ba4663e8bdd5d6fe54c8a939a99e456d66080` de V1.3.

## Livrables

Code applicatif construit : `f73a8e13c72173362630648513ffe81020b0e727`.
Les documents ajoutés ensuite ne modifient pas ce code ni le workflow.

- [Run final réussi](https://github.com/tiviniura0/living-memory-android/actions/runs/40654444799).
- [Archive APK à extraire](https://github.com/tiviniura0/living-memory-android/actions/runs/40654444799/artifacts/12801572866).
- [Preuves légères](https://github.com/tiviniura0/living-memory-android/actions/runs/40654444799/artifacts/12801847492).
- Version 1.3.1+5 ; uniquement `arm64-v8a` ; **901 387 062 octets**.
- SHA-256 APK : `91b5d4f7671f2ef831294f07da8f3cdd1d4e8c7d46e1288410cc54e64009edcb`.
- Certificat SHA-256 : `c3f798c5aae7bf31e6cab687b93e583978feb5dc342295edf008a736fc7498d7`.
- Signature v2 valide ; certificat **Android Debug expérimental, non pérenne**.
- Expiration de l'archive APK : **10 novembre 2026 à 22:21:34 (Tahiti)**.

Le certificat diffère de celui de l'artefact V1.3 documenté. Cet APK ne peut pas
le mettre à jour par installation normale. **Ne pas désinstaller une version
contenant des données** ; retrouver sa clé et suivre SIGNING.md.

L'APK complet a été compilé et inspecté dans Actions. Les preuves légères ont
été téléchargées ici et leur ZIP revérifié contre le digest GitHub :
`744ecd1a26beb4147fa748a38ef3162957339d891af727322ade398751c12d47`.
L'APK complet n'a pas été retéléchargé localement. BUILD.json et evidence/
conservent les métadonnées, signature, manifeste fusionné et dépendances.

## Corrections apportées

1. Chiffrement SQLCipher de la mémoire SQLite Android, incluant vecteurs,
   index FTS et archives. Clé aléatoire enveloppée AES-GCM par Android Keystore,
   écriture atomique de l'enveloppe et refus sans clé valide. Migration par
   export, contrôles HMAC/SQLite/FK et comparaison des tables avant remplacement.
   Aucun reset de secours, même profil et schéma applicatif 4. Voir STORAGE.md.
2. Fuite de transcription reproduite puis retirée. Sinks du point d'entrée
   pour debugPrint, print de la zone, erreurs Flutter/dispatcher sans contenu ;
   LiteRT-LM natif silent. Les données ne deviennent pas des journaux de debug.
3. Effacement distinct : source et dérivés ; session et ses décisions/résumés ;
   agent et tous ses projets. Confirmations UI, index FTS secure-delete, autres
   agents/modèles préservés. Une source supprimée ne purge pas ses copies dans
   des historiques indépendants ; l'interface l'indique.
4. Modèles : HTTPS validé au transport, redirections contrôlées, pas de userinfo
   ou fragment, bornes de taille partagées jusqu'au fichier local/registre et
   copie bornée. Empreinte malformée refusée avant I/O ; intégrité et taille
   réelle contrôlées avant commit. Liens signés : requête conservée, fragment
   retiré à l'UI, secrets non enregistrés dans la provenance.
5. Release sans clé externe refusée sauf opt-in debug expérimental explicite.
   Procédure de signature stable, coffre et restauration testée documentés.
   Aucune clé de signature de production créée. Même applicationId. Voir SIGNING.md.

Le code du moteur RAG/ReliabilityEngine, AutoMemoryEngine, AssistantSession et
MultiModelEngine est conservé ; le registre ne change que pour les bornes de
sécurité. Le lockfile, les poids publics, les profils d'embedding et les interfaces
Living World AI sont conservés. Leur présence n'est pas une preuve de génération
réelle ou d'intégration serveur.

## Validation logicielle et audit

**3 060 tests réussis, 15 ignorés**, aucune erreur ; **147 tests ciblés réussis**.
Analyse et formatage réussis. Les cinq groupes de sécurité et modèles locaux
passent également séparément (2, 8, 6, 4 et 74 tests). Les tests
Flutter couvrent SQLite/SQLCipher réels et petits fichiers réels ; inférence,
I/O audio, callbacks système et certains chemins d'erreur restent simulés.
Ils ne prouvent pas le fonctionnement de la bibliothèque ARM64 sur S22.

Les preuves rouges puis vertes et la suite complète finale couvrent transcription, migration et mauvaise
clé, transport, borne locale avant inspection/copie et callback d'effacement
échoué. Un test migre une base avec trous dus à des suppressions historiques et
vérifie les deux index FTS puis leur suppression. La revue indépendante en
lecture seule et ses décisions figurent dans REVIEW.md.

Nouveau scan OSV : 152 entrées (148 Pub, 4 Maven), puis 147 coordonnées Maven
baseline, aucun avis retourné. Réponses brutes conservées ; absence d'avis ne
certifie pas tous les binaires natifs. Archive sqlite3 3.7.1 vérifiée contre le
SHA-256 de pubspec.lock ; provenance du binaire SQLCipher dans NATIVE_PROVENANCE.json.
Les notices SQLCipher/OpenSSL sont ajoutées aux licences et à l'écran existant.
Les licences des modèles/SDK, dont YOLO AGPL-3.0 et Gemma, restent applicables.

Contrôles Android conservés : pas de stockage étendu, export limité au launcher
et aux composants système protégés attendus ; sauvegardes/transfert exclus,
release non débogable et HTTP désactivé dans le manifeste. Le manifeste fusionné
et le graphe natif résolu ont été contrôlés après compilation. Les 147
coordonnées/version finales sont exactement celles interrogées par OSV ;
Guava 33.7.2-android et OkHttp 4.9.2 résolus. Les contrôles du manifeste
fusionné ont aussi été relancés ici avec succès. La caméra réseau des
démos est un parcours distinct du téléchargement de modèles durci ici.

12 tests Python locaux (7 Android/dépendances, 5 parseur de signature) ont été
exécutés avec succès. Les tests du parseur ne valident pas à eux seuls un APK.
Le formatteur Dart autonome est utilisable. Le lancement local de Flutter a été
rejeté par l'approbation automatique pour une tentative d'accès aux métadonnées
cloud 169.254.169.254 : aucun contournement, tests/builds via Actions.

## Risques résiduels et S22

- Aucun essai matériel : Keystore réel/reboot/corruption, conversion sur S22,
  arrêt forcé/panne, espace réellement plein, logs natifs complets, permissions,
  sauvegardes OEM, mode avion, E2B/E4B/vision/STT/TTS réels restent à tester.
- Aucune mesure de RAM, chauffe, batterie ou latence. La conversion synchrone
  copie et compare toute la base ; elle peut bloquer l'UI et requiert de l'espace
  temporaire. La gestion des ANR et la durabilité du remplacement après panne
  nécessitent un essai sur téléphone. Aucun effacement physique flash garanti.
- Perte de Keystore/enveloppe sans export complet : données potentiellement
  irrécupérables. Les données restent en mémoire durant l'usage ; chaînes Dart,
  RAM native et anciens journaux système ne sont pas garantis effacés.
- La suppression d'une source ne supprime pas une réponse copiée dans une autre
  session/source. Effacer les scopes concernés explicitement. Les copies externes
  ou captures ne sont pas sous contrôle de l'application.
- Chiffrement limité à la mémoire SQLite Android : modèles, manifestes et
  réglages restent privés mais non chiffrés par cette couche ; desktop inchangé.
  Les sinks Dart ne couvrent pas automatiquement de nouveaux isolates ou tous
  les SDK natifs. Les diagnostics de console sont volontairement réduits.
- URL personnalisée HTTPS et SHA-256 calculé ne certifient pas l'éditeur.
  Fournir un hash provenant d'une source de confiance quand il existe. Copies
  SAF initiales non annulables ; pas de certification de tous les formats natifs.
- Signature CI debug non pérenne. Comparer le certificat installé avant toute
  mise à jour ; en cas de différence, conserver l'application et retrouver la
  clé originale. Ne jamais désinstaller pour contourner ce refus.

Le protocole détaillé est INSTALL_S22.md. Le test Android dédié est
`integration_test/security_storage_device_test.dart` : préparé, non exécuté.
Aucune fusion ni modification de branche stable. Ce livrable reste expérimental.

## Permissions réellement empaquetées

| Permission | Usage ou décision d'audit |
|---|---|
| INTERNET | Téléchargements de modèles et caméra réseau des démonstrations |
| CAMERA | Sélection/capture et caméra existantes ; autorisation au geste à vérifier sur S22 |
| RECORD_AUDIO | Capture/dictée ; autorisation au geste à vérifier sur S22 |
| ACCESS_NETWORK_STATE | État réseau des dépendances d'installation/téléchargement |
| VIBRATE | Permission transitive conservée ; nécessité précise non démontrée par cet audit |
| WAKE_LOCK, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE | Permissions transitives conservées pour compatibilité ; nécessité et activation réelles restent à minimiser/valider sur appareil |
| DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | Permission propre au paquet, niveau signature ; protection interne |

Pas de READ/WRITE/MANAGE_EXTERNAL_STORAGE, pas de POST_NOTIFICATIONS dans le
badging inspecté. Les quatre composants exportés autres que le launcher ont
leurs permissions exactes BIND_JOB_SERVICE ou DUMP. Aucun nouveau composant
exporté par le canal Keystore. Conserver des permissions transitives n'est pas
une preuve qu'elles sont toutes indispensables : leur réduction reste une
amélioration à tester sans casser les parcours existants.

L'asset SQLCipher brut du hook et l'ELF empaqueté ont des empreintes consignées
séparément (NATIVE_PROVENANCE.json et BUILD.json). Le contrôle APK vérifie sa
présence et ses symboles SQLCipher ; il ne prétend pas qu'un fichier après
traitement de build est identique octet pour octet à l'asset brut.

La comparaison explicite des rowid implicites pendant la conversion est une
amélioration de vérification différée, sans défaut démontré : la fixture réelle
de suppressions historiques, FTS et suppression après migration passe avec le
moteur épinglé. Les limites matérielles mises à part par la revue restent celles
listées ci-dessus et ne sont pas comptabilisées comme des succès simulés.
