# Validation S22 de Living Memory V1.4

Aucun appareil n'a été utilisé pour les preuves CI. Ce protocole reste à exécuter.
Conserver les procédures [signature](../v1.3.1/SIGNING.md) et
[stockage](../v1.3.1/STORAGE.md) V1.3.1, ainsi que le protocole historique
[INSTALL_S22](../v1.3.1/INSTALL_S22.md).

## Avant installation

Comparer le certificat SHA256 du paquet installé avec apk-signature.txt de
l'artefact. Un APK expérimental signé debug n'est pas une signature stable.
Ne pas désinstaller, vider les données ou remplacer une clé pour contourner un
refus Android. Le retour à un ancien APK ne signifie pas que son schéma accepte
la base migrée en version5. Faire un transfert chiffré et conserver la clé de
récupération séparément avant une opération de maintenance.

## Scénario fonctionnel

1. Vérifier mémoire personnelle et agents/projets historiques, recherche FTS,
   RAG, revue Auto-Memory et choix Gemma E2B/E4B avec les modèles disponibles.
2. Ouvrir Living World : moteur L1 local, monde en pause entre les actions.
   Avancer12ticks et relever tick/source dans la mémoire. Aucune génération
   autonome des habitants n'est annoncée à ce jalon.
3. Ajouter une déclaration privée de A. Consulter B : absence de cette source.
   Partager explicitement avec B, consulter B, vérifier le statut de déclaration,
   révoquer puis vérifier l'absence de nouvel accès. Une copie déjà citée n'est
   pas effacée rétroactivement.
4. Fermer puis rouvrir ; vérifier checkpoint, reçus idempotents et souvenirs.
   Simuler une interruption avant synchronisation et vérifier le retry avant
   toute nouvelle avance.
5. Extensions : approuver le Skill, autoriser une lecture unique, planifier une
   lecture puis autoriser son exécution au premier plan. Aucun lancement en
   arrière-plan ni accès implicite au téléphone ou à un serveur MCP.
6. Transfert : exporter via le sélecteur Android ; conserver la clé séparément.
   Restaurer avec cette clé vers un fichier candidat distinct ; vérifier que
   l'espace actif reste ouvert et inchangé. Vérifier annulation, mauvaise clé,
   stockage insuffisant et reprise après interruption. La restauration ne
   sélectionne pas automatiquement le candidat.

## Mesures et limites matérielles

Exécuter mode avion, redémarrage/Keystore, pression mémoire, chauffe, batterie,
espace plein et interruption d'écriture. Relever versions Android, ABI,
modèles et empreintes utilisés. Les doubles d'embedding et canaux Android des
tests ne constituent pas une preuve d'inférence ou de SAF sur appareil.
