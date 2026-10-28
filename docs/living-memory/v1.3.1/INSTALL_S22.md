# S22 Ultra — V1.3.1 expérimentale : validation non exécutée

Aucun essai matériel effectué par cette mission. Ne jamais installer cet APK
par désinstallation d'une version contenant des données.

## Avant installation

Télécharger uniquement l'artefact APK du run final réussi de REPORT.md ; extraire
app-release.apk et les preuves. Vérifier son SHA-256, ARM64, version 1.3.1+5 et
`apksigner verify --verbose --print-certs`. Relever le certificat de base.apk
installé avec `adb shell pm path com.google.ai.edge.examples.litert_edge_demos`,
`adb pull` puis apksigner. Si différent, suspendre la mise à jour : suivre
SIGNING.md et retrouver la clé d'origine. Ne pas désinstaller, effacer les données
ou considérer une installation parallèle comme une migration. Si certificat
compatible seulement : `adb install -r app-release.apk`.

L'APK CI est signé debug avec un opt-in expérimental ; sa clé n'est pas pérenne.
Il convient à une installation de test vierge et ne garantit pas la mise à jour
V1.3. Aucun export/restauration complet de l'application n'est disponible.

## Essais à consigner

Utiliser exclusivement des données synthétiques. Relever commit, hash APK,
certificat, Android/One UI, variante/SoC exact du S22, modèle/hash/backend,
espace libre et heure. Mesures non exécutées : ne pas remplir par estimation.

| Essai | Critère | Statut |
|---|---|---|
| Mise à jour compatible | Conserver agents, sources, décisions, sessions, anciens résumés et choix E2B/E4B | non exécuté |
| Conversion | Migration d'une vraie base V1.3 avec suppressions historiques ; FTS/RAG identiques, réouverture après redémarrage | non exécuté |
| Base chiffrée | Aucun texte synthétique dans DB/journal/WAL ; copie inutilisable sans enveloppe/Keystore | non exécuté |
| Keystore | Clé réutilisée après arrêt/reboot ; pas de reset si enveloppe/clé indisponible, sur installation de test sacrifiable seulement | non exécuté |
| Échec de migration | Peu d'espace, arrêt forcé avant/pendant export et autour du remplacement : reprise sans perte de l'original | non exécuté |
| Performance | Ouverture/migration et 100 recherches sur même corpus ; RAM, chauffe, batterie et absence d'ANR | non exécuté |
| Source | Effacer passages/souvenirs/révisions/liens ; copies de sessions restent conformément au message | non exécuté |
| Session | Annulation sans effet ; confirmer retire messages/décisions/résumés et vue active, sources indépendantes restent | non exécuté |
| Agent | Effacer tous ses projets et archives ; deuxième agent et modèles intacts | non exécuté |
| Modèles | HTTPS/CDN, taille/hash incorrects, fichier altéré, disque plein, annulation/reprise, provenance non vérifiée explicite | non exécuté |
| Logs | Sentinelles synthétiques dans chat/dictée/image/erreurs/URL signée ; aucune sentinelle dans logcat ni fichiers de logs | non exécuté |
| Permissions | Micro/photo au geste, refus/annulation, aucun stockage étendu ni sauvegarde/transfert système | non exécuté |
| Fonctions V1.3 | Texte, RAG/citations, PDF/TXT, image choisie, WAV/dictée française, TTS/arrêt et interruptions | non exécuté |
| Modèles réels | E2B puis E4B séparés puis Auto ; fermeture séquentielle, RAM/OOM et arrêt natif | non exécuté |
| Hors ligne | Après préparation, mode avion + Wi-Fi/données coupés : chaque parcours séparément | non exécuté |

Le test `integration_test/security_storage_device_test.dart` prépare un contrôle
réel Android Keystore + SQLCipher avec un fichier synthétique isolé. Il n'est
pas exécuté par `flutter test`. Le lancer sur un appareil autorisé dans une
installation de test appropriée ; il ne valide pas à lui seul le redémarrage,
la panne d'alimentation ou la migration d'une base de production.

Pour les mesures système : `adb shell dumpsys meminfo` avec l'applicationId,
`adb shell dumpsys thermalservice`. Ne pas publier de dumps personnels.
Ne pas joindre de clés, transcriptions réelles ou URL signées aux preuves.
