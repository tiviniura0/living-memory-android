# Audit V1.3.1 — sécurité expérimentale

Base vérifiée : b77ba4663e8bdd5d6fe54c8a939a99e456d66080, branche V1.3.
Les quatre documents AUDIT.md, REPORT.md, REVALIDATION.md et INSTALL_S22.md de
V1.3 ont été lus intégralement. Le périmètre est l'application
samples/litert/flutter, ses composants Kotlin, la chaîne de build et les SDK
qu'elle embarque ; ce n'est pas une certification de chaque démo du monorepo.
Aucun S22, émulateur Android ni autre appareil physique utilisé.

## Corrections

- SQLite privé : SQLCipher sélectionné dans le hook sqlite3 3.7.1 verrouillé ;
  base/FTS/vecteurs/archives chiffrés sur Android. Enveloppe AES-GCM AndroidKeyStore,
  AtomicFile dans noBackupFilesDir, aucune clé hardcodée ou export de la clé
  Keystore. Refus d'ouverture sans clé valide, jamais de reset de secours.
- Migration : conversion vers fichier chiffré séparé, contrôles d'intégrité,
  HMAC/FK et comparaison intégrale avant remplacement. Schéma 4 et profil
  conservés. Détails et limites de performance dans STORAGE.md.
- Journaux : fuite de transcription complète reproduite par un test rouge,
  corrigée à la source ; fin de transcription sans texte/raison brute. Le point
  d'entrée installe avant les plugins des sinks sans contenu pour debugPrint,
  print de la zone Dart, erreurs Flutter et erreurs du dispatcher. LiteRT-LM
  utilise son niveau natif silent. Les logs tiers/natifs et leur comportement
  matériel restent à vérifier ; aucun balayage d'un téléphone n'est revendiqué.
- Effacement : secure_delete et secure-delete FTS5 ; source et descendants,
  session avec décisions et deux tables de résumés, agent avec tous ses projets.
  Confirmation UI pour session/agent et nettoyage de la vue. Suppression d'une
  source ne promet pas d'effacer ses copies dans des historiques indépendants.
- Modèles : contrôle HTTPS dès le transport, refus userinfo/fragment et
  redirections non sûres ; 1 octet à 8 Gio, taille réelle et SHA-256 vérifiés
  avant commit. Les empreintes fournies doivent être 64 caractères hexadécimaux.
  L'opt-in HTTP loopback existe uniquement pour les serveurs de test et n'est
  activé dans aucun appel de production. Les imports SAF restent bornés et la
  source d'origine est conservée. Les CDN HTTPS arbitraires restent permis :
  l'origine n'est pas authentifiée sans empreinte obtenue d'une source fiable.
- Signature : release sans clé stable externe refusée sauf opt-in explicite
  pour un APK expérimental debug. Aucune clé de signature de production créée,
  aucun secret ajouté à GitHub. Procédure de conservation/restauration et
  comparaison de certificat obligatoire dans SIGNING.md. Même applicationId.

## Android et dépendances

Les permissions caméra/micro restent demandées à l'action ; import SAF, aucune
permission de stockage étendue. Launcher seul exporté sans garde ; les services
et receivers transitifs attendus doivent garder leurs permissions système exactes.
allowBackup=false, fullBackupContent=false, exclusions cloud/device-transfer et
HTTP désactivé restent contrôlés sur source ET manifeste fusionné. Le canal
Keystore est interne au moteur Flutter ; aucun nouveau composant Android exporté.

pubspec.lock inchangé ; pas de mise à jour globale. Les contraintes Guava
33.7.2-android et OkHttp 4.9.2 de V1.3 sont conservées et contrôlées sur le graphe
résolu. Nouveau contrôle OSV : 152 entrées (148 Pub, 4 Maven) et 147 coordonnées
Maven de la baseline, aucun avis retourné ; JSON bruts conservés. Le graphe
résolu final doit être comparé à celui interrogé après le build. Les SDK natifs,
les pilotes GPU/NPU, PDFBox, QNN, LiteRT et les bibliothèques .so précompilées
ne sont pas entièrement couverts par OSV Pub/Maven.

Le nouveau binaire SQLCipher provient du hook officiel de sqlite3 3.7.1 ; son
SHA-256 Android ARM64 attendu dans le paquet est
8308570993f1e7dd0742c1cbc82b587951ca724830bf18d5e4948ed34574db40.
Le changelog du paquet annonce SQLCipher 4.19.0 et OpenSSL 4.0.3. Le SHA du
binaire effectivement empaqueté est conservé avec les preuves APK. Les tests
SQLCipher exécutés sous Linux ne sont pas une exécution du binaire Android.
Les conditions et notices existantes des modèles et SDK restent applicables.

## Preuves et limites

Run rouge initial 40650705154 : transcription synthétique reproduite dans le
journal. Run 40651513235 : vérifications de transport refusées trop tard
et contrôle de migration reproduits avant correction (voir historique Actions ;
seuls les identifiants exacts validés figurent dans le rapport final).
Le premier correctif de migration a révélé SQLITE_CANTOPEN : la connexion source
sans CREATE interdisait la création du fichier attaché. Ouverture corrigée ;
les tests de migration complète passent ensuite.

Les résultats définitifs, liens APK/signature/hash et nombres de tests doivent
être lus dans REPORT.md et BUILD.json du même code. Ce document décrit les
contrôles, ne transforme pas un run en cours en succès.

Localement : contrôles Python Android/signature/dépendances et formatteur Dart
indépendant utilisables. Le lancement de Flutter a été rejeté automatiquement
pour un accès à 169.254.169.254 ; aucun contournement, exécution via Actions.
Graphify indisponible : cartographie par lecture/recherche, aucun graphe inventé.

Risques ouverts : clé ou enveloppe perdue sans export complet, signature des
anciennes installations potentiellement irrécupérable, migration synchrone
coûteuse et crash/panne d'alimentation non testés, copies flash non effaçables de
façon garantie, données en RAM native et logs tiers non certifiés, modèles
personnalisés non authentifiés sans hash fiable, copie SAF initiale non annulable.
Aucune mesure de RAM, chauffe, batterie, latence ou qualité d'inférence S22.
