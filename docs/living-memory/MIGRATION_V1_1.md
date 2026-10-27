# Migration non destructive V1 -> V1.1

Fichier inchangé : `living-memory-v1.db` dans le stockage privé Android. `kb.db` des démos n'est jamais ouvert par MemoryStore.

1. Refuser une version future avant écriture ; vérifier le nom et la dimension du profil d'embedding existant.
2. V1 sans user_version -> schéma 2 : tables souvenirs, réglages opt-in, liens, révisions et suivi des passages (implémentation préexistante).
3. Schéma 2 -> 3 : transaction additive, colonnes projet/monde vides par défaut, FTS5 des chunks et triggers de synchronisation, archives et checkpoints de session. Rebuild FTS initial ; aucun recalcul des vecteurs.
4. Schéma 3 -> 4 : table append-only de checkpoints avec copie des checkpoints existants, index FTS5 des messages et triggers. La table de checkpoints V3 reste intacte. Les nouvelles écritures utilisent les événements V4. Les réponses IA et les questions ne sont pas des sources RAG.

Les anciens documents gardent leurs identifiants, vecteurs et digest. Pour les nouveaux imports dans une portée projet/monde non vide, la clé de déduplication dérive du digest et de cette portée ; le même document peut appartenir à deux projets sans être partagé implicitement. La limite de 10 000 passages reste globale par agent.

Les checkpoints contiennent des extraits attribués et des numéros de message ; les originaux restent présents. Le reset ajoute un checkpoint vide et ne supprime aucune ligne de document, souvenir ou message. L'archivage d'un souvenir ajoute une révision et le retire de la recherche des souvenirs confirmés ; sa source demeure recherchable. Une suppression explicite de source garde le comportement V1 : cascade des chunks et souvenirs liés.

Une migration SQL échouée est annulée ; une ancienne APK ne peut pas ouvrir une version de schéma future. Retour logiciel vers V1 après migration non pris en charge. Prévoir un export/restauration avant une diffusion durable ; ne pas copier un fichier SQLite ouvert.

L'installation sur une V1 réelle dépend aussi de la signature Android. Les certificats debug des runners ne sont pas garantis identiques. Une désinstallation détruit les données privées : ne pas l'utiliser pour contourner une incompatibilité de signature.
