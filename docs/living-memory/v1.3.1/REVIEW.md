# Revue indépendante V1.3.1

Revue en lecture seule du diff b77ba466..645712f3 par un agent distinct.
Aucune mutation ni exécution Flutter locale par le reviewer.

- Aucun problème critique confirmé dans la revue des sources.
- Important : sélection locale et copie au registre hors borne 8 Gio. Tests
  par fichiers creux reproduits rouges avant correction ; validation partagée
  ajoutée avant inspection, adoption, chargement du registre et copie bornée. Les chemins import/téléchargement étaient déjà bornés.
- La migration avec trous de rowid FTS a été examinée : aucune corruption
  confirmée dans l'implémentation SQLCipher épinglée (optimisation de transfert
  des tables indexées). Une fixture de suppressions historiques a été ajoutée.
- Callback de suppression appelé même après erreur : reclassé à corriger,
  pour ne pas nettoyer la vue comme si l'effacement avait réussi. Test d'erreur
  simulée observé rouge (callback appelé à tort), puis callback déplacé dans
  le bloc de succès. La validation finale doit confirmer les corrections.
- Couverture étendue : empreinte malformée et credentials/fragments de
  redirection ; Keystore réel/interruption matérielle restent non exécutés.

Limites mises à part par la revue et retenues explicitement : comportement
Keystore/reboot/S22 et inférence réelle, mesures de performance, panne
matérielle et effacement flash, logs natifs complets, compatibilité du certificat
installé. Ces points nécessitent les essais du protocole INSTALL_S22.md et ne
sont pas validés par des tests Linux ou des doubles.

La revue ne constitue ni une certification de sécurité ni une autorisation de
fusion stable. Le verdict exige la correction de la borne locale et une CI/APK
entièrement réussie. REPORT.md consigne l'état final et les risques résiduels.
