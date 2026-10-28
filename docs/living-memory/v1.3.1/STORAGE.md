# Stockage et migration V1.3.1

## Périmètre

Sur Android, `living-memory-v1.db` utilise SQLCipher : tables utilisateur,
textes, vecteurs, FTS, décisions et les deux générations de checkpoints. Le
schéma applicatif reste à 4. `sqlite3` reste verrouillé à 3.7.1 ; son hook passe
à `source: sqlcipher`, sans remplacement global des plugins. La base publique
`kb.db` des démonstrations n'est ni migrée ni chiffrée. Sur les autres plateformes,
MemoryScreen conserve son stockage existant en clair ; le chemin chiffré est
testé avec des clés synthétiques sur Linux, pas présenté comme un Keystore desktop.
Les poids publics/personnels, les manifestes de modèles et les réglages ne sont
pas chiffrés par cette couche. Ils ne doivent pas servir d'archives de prompts.

## Clés

Une clé de base aléatoire de 32 octets est générée **sur l'appareil**. Une clé
AES-256 non exportable AndroidKeyStore l'enveloppe avec AES-GCM, IV aléatoire
fourni par Cipher, tag 128 bits et AAD versionné. L'enveloppe est écrite par
AtomicFile dans noBackupFilesDir puis relue/authentifiée avant utilisation.
Aucun matériel de clé ne passe dans GitHub, les logs ou les rapports. Seule la
clé SQLCipher déchiffrée passe temporairement par le canal Flutter privé de
l'application ; la clé Keystore n'est jamais exportée. Les tableaux Kotlin sont
remis à zéro ; les chaînes Dart et copies FFI ne peuvent pas être garanties
exemptes de rémanence en mémoire. `cipher_memory_security=ON` complète cette limite.

La clé n'est pas liée à une empreinte biométrique : un changement d'empreinte
ne doit pas invalider les données. Aucune authentification par agent n'est
ajoutée. Une clé/enveloppe absente avec une base chiffrée, une enveloppe corrompue
ou une erreur Keystore bloque l'ouverture : aucune nouvelle base, aucun reset,
aucune suppression automatique de clé. Perdre l'installation/Keystore peut
rendre la base irrécupérable ; il n'existe pas encore d'export/restauration
complet. La clé de signature APK est entièrement distincte (SIGNING.md).

## Conversion depuis V1.3

1. Verrou de migration dans le répertoire privé ; refus des liens symboliques.
2. Détection de l'en-tête SQLite en clair ; vérification du schéma futur,
   integrity_check et foreign_key_check. Aucun profil incompatible n'est effacé.
3. Checkpoint WAL et retour DELETE obligatoires ; une base occupée est refusée.
4. Export SQLCipher vers un fichier chiffré temporaire du même répertoire.
   L'original reste présent. synchronous=FULL et temp_store=MEMORY.
5. Réouverture avec la clé ; intégrité SQLite/HMAC/FK ; comparaison des lignes
   et nombres de lignes de toutes les tables, y compris FTS et archives.
6. Fermeture des connexions et remplacement atomique par rename. Aucun backup
   en clair conservé. Un export interrompu peut être repris après validation de
   l'original ; un original chiffré n'est jamais considéré comme une base neuve.

Un manque d'espace ou une erreur avant remplacement laisse la base d'origine
utilisable. Les tests avec obstacle de fichier simulent une erreur d'export ;
ils ne reproduisent pas une panne d'alimentation ou un vrai disque plein sur S22.
Le comportement de durabilité du répertoire sur ext4/F2FS doit être testé sur
appareil ; pas de garantie de résistance à toute panne matérielle. L'effacement
physique des anciens blocs flash n'est pas garanti (wear levelling).

## Coûts à mesurer

Aucune latence ou consommation S22 n'a été mesurée. La conversion requiert une
copie complète chiffrée et de l'espace temporaire en plus de l'original ; la
comparaison intégrale ajoute du temps et peut employer du tri temporaire en
mémoire. Le moteur conserve ses paramètres SQLCipher par défaut. La clé brute
à forte entropie évite de traiter un mot de passe humain comme clé. Les lectures
RAG restent identiques au niveau SQL, mais chiffrement/HMAC, FTS secure-delete
et remise à zéro mémoire ajoutent un coût. L'ouverture/migration est synchrone
sur l'isolate UI existant : une grosse migration peut bloquer l'interface.
Mesurer avant redistribution : temps d'ouverture à froid, migration, 100 recherches
FTS/vectorielles, ajout/suppression de sources et RAM/chauffe/batterie. Comparer
au même corpus synthétique V1.3 avec la même signature compatible.

## Suppressions

- Source : chunks, souvenirs dérivés, révisions, liens et batches via FK ;
  historiques et checkpoints indépendants conservés, message UI explicite.
- Session : messages, décisions et les deux tables de checkpoints via FK ;
  les sources enregistrées séparément restent.
- Agent : toutes ses sources/souvenirs/révisions/liens/batches, réglages Auto-Memory,
  sessions/décisions/checkpoints de tous ses projets ; autres agents et modèles
  préservés. Transaction atomique et vue active nettoyée.

secure_delete SQLite et secure-delete FTS5 sont activés. Une suppression logique
ne certifie ni l'effacement physique flash, ni le nettoyage de toute RAM native,
ni l'effacement de copies/exportations créées hors de l'application.

## Sources primaires consultées

- https://pub.dev/packages/sqlite3/versions/3.7.1
- https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html
- https://www.zetetic.net/sqlcipher/sqlcipher-api/
- https://developer.android.com/privacy-and-security/keystore
- https://developer.android.com/privacy-and-security/cryptography
- https://www.sqlite.org/fts5.html#the_secure_delete_configuration_option
