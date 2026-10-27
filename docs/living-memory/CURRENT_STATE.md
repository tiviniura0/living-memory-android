# État Living Memory V1.2 — expérimental

Branche : work/living-memory-v1.2-multimodel.
Source V1.1 préservée : fe9c0af4acc9a2fc28fcef0c38ee5638425c778d.
Version applicative : 1.2.0+3 ; applicationId et base SQLite schéma 4 conservés.
Aucune fusion dans main.

Implémenté : registre privé de modèles, abstraction LocalModelRuntime,
adaptateur LiteRT-LM réel, modes Auto/E2B/E4B, déchargement séquentiel avant et
après tâche, repli E4B vers E2B sur erreur récupérable, arrêt des chargements
si fermeture native en échec, provenance du modèle, préférences V1.1 préservées.
EmbeddingGemma 2 et l'espace vectoriel 768 restent inchangés.

Les preuves du build sont dans l'artefact Actions associé au commit exact :
apk-metadata.json, APK-SHA256.txt, signature, logs ciblés et suite complète.
Le rapport de l'artefact contient le lien exact du run qui l'a produit.
Une archive de preuves peut exister même si le run échoue : vérifier le statut
final ET la présence de app-release.apk avant de parler d'APK validé.

Tests matériels : NON EXÉCUTÉS. Ni E4B réel, ni RAM, ni chauffe, ni débit
sur Galaxy S22 Ultra n'ont été validés dans cet environnement.
Voir V1_2_VALIDATION.md et V1_2_S22_PROTOCOL.md.

Attention signature : certificat debug Actions non pérenne. Ne pas désinstaller
une application contenant des données pour forcer une mise à jour incompatible.
Aucun export/restauration n'est actuellement disponible.
