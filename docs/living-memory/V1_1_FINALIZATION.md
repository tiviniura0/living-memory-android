# Living Memory V1.1 — finalisation du 27 octobre 2026

Branche : `work/living-memory-v1.1-auto-memory`. Aucun changement de main.

## Diagnostic prouvé et correction

Le run [40483246647](https://github.com/tiviniura0/living-memory-android/actions/runs/40483246647)
sur b4d660bce1d27f9faef42d0c75c8553b647611e2 termine 59 tests Living Memory,
2 990 tests complets et 15 ignorés. Analyse et format réussissent ; compilation
ARM64 réussie. L'étape suivante échoue avec `AssertionError: Missing signer digest`.
Apksigner avait validé la signature v2 ; son texte utilise `V2 Signer:` au lieu de
`Signer #1`. Le correctif 26dd28e2 accepte ces deux formats et refuse les identités
ambiguës. Les cinq régressions Python ont été réexécutées avec succès ici.

La nouvelle compilation réexécute tests ciblés, format, analyse, suite complète,
build, validation de signature et ABI. Le SHA-256 de l'EmbeddingGemma empaqueté
est désormais comparé à tool/models.lock, en plus de sa taille. Le commit exact,
le certificat et hardware_tested=false sont enregistrés dans apk-metadata.json.
Les résultats définitifs sont les logs et métadonnées de CE run, pas ceux du run précédent.
L'artefact contient aussi ce rapport ; sa présence seule ne prouve pas le succès :
vérifier que toutes les étapes du run sont vertes.

## Couverture opérationnelle et limites

| Composant | Ce que vérifient le code et les tests automatisés | Limite matérielle / sémantique |
|---|---|---|
| Extraction | opt-in par agent, sortie JSON stricte, citation exacte, bornes, annulation, reprise | Inférence réelle Gemma et français non testés sur S22 |
| Déduplication | idempotence et classement cosinus local ; portée agent/projet/monde | Vecteurs de test synthétiques ; seuils non calibrés |
| Provenance | document, page, passage, citation, dates, extracteur, versions | Une citation peut être fausse ou tronquée dans son contexte |
| Contradictions | mêmes clés sujet/relation et valeurs différentes signalées | Clés du modèle non garanties ; pas de vérification universelle |
| Consolidation | regroupement explicite sans perdre les sources, correction versionnée | Pas de résolution sémantique autonome |
| Isolation | agents et portées de sessions/projets, tests de refus croisés | Application mono-utilisateur ; pas de serveur multiutilisateur |
| Contexte | checkpoints extractifs, décisions attribuées, archives conservées, reset non destructif | Estimation conservatrice en octets ; pas de mesure exacte de tokens |
| Migration | SQLite réel temporaire ; conservation V1 et migration jusqu'au schéma 4 | Base personnelle du téléphone non testée |
| Réponse RAG | citations et abstention structurelles, exclusion des citations dans le code | Ne prouve pas que chaque phrase découle des sources |

Les tests utilisent SQLite réel, des doubles de conversation et des vecteurs
synthétiques. Ils ne chargent pas les poids IA dans un appareil Android.
GemmaMemoryExtractor appelle réellement ConversationRepository puis LiteRT-LM.
Le parcours UI utilise embedDocuments pour les candidats et le même service V1
pour la recherche ; ModelRepository prépare le fichier EmbeddingGemma embarqué.
Gemma 4 E2B doit être importé séparément au format .litertlm. Le test utilisateur
dans AI Edge Gallery ne valide pas cette application distincte.

## Préservation des données : blocage à ne pas contourner

Même applicationId et même base living-memory-v1.db ; schéma 4 additif.
Le certificat du précédent APK V1.1 (924b228c…eccc) diffère de la V1 de référence
(cc90f8b4…c487). L'empreinte du nouveau build figure dans apk-metadata.json.
Les clés debug des runners ne sont pas pérennes. Une signature valide ne signifie
pas qu'une mise à jour sur V1 est acceptée. La clé privée V1 n'est pas récupérable
depuis l'APK. Aucun export/restauration des données V1 n'existe actuellement.
**Conserver V1 installée si elle contient des données ; ne jamais désinstaller pour
forcer cette V1.1.** Le retour vers l'ancienne APK après migration SQL n'est pas pris en charge.
La distribution durable reste bloquée par la signature pérenne et la sauvegarde.

## Installation et essai S22 Ultra

1. Dans le run entièrement réussi correspondant au commit indiqué par apk-metadata.json,
   télécharger l'artefact living-memory-android-COMMIT. Être connecté à GitHub.
2. Extraire le ZIP ; ouvrir app/outputs/flutter-apk/app-release.apk. Autoriser
   l'installation depuis le gestionnaire de fichiers si Android le demande.
3. Si V1 est déjà installée avec des données : ne pas poursuivre en cas de refus
   de signature et ne pas la désinstaller. Une installation neuve sans données V1
   permet les essais ci-dessous.
4. Importer le fichier générique gemma-4-E2B-it.litertlm depuis Téléchargements.
   Celui stocké dans l'espace privé d'AI Edge Gallery n'est pas partagé automatiquement.
   Essayer GPU puis CPU si échec explicite ; ne pas choisir une variante NPU d'un autre chipset.
5. Dans Living Memory, ajouter une note de démonstration, activer Auto-Memory pour
   cet agent et consulter les candidats. Vérifier la citation et la provenance
   avant confirmation. Reprendre la source au-delà de huit passages.
6. Réimporter la note, tester une valeur contradictoire et un deuxième agent.
   Vérifier l'absence de fuite entre agents ; corriger/regrouper puis rouvrir l'application.
7. Importer un TXT et un PDF texte ; les PDF scannés n'ont pas d'OCR.
   Marquer une décision, compacter puis réinitialiser le contexte : les originaux
   doivent rester disponibles.
8. Après préparation des modèles, redémarrer en mode avion et refaire recherche,
   extraction et génération. Mesurer durée, RAM, chauffe, arrêt et batterie.

Aucune installation, inférence native, mesure de performance ni validation de
migration sur ton téléphone n'a été réalisée dans cette session. Aucune promesse
de fonctionnement permanent en arrière-plan. Stockage privé Android sans
chiffrement applicatif ; aucun service mémoire cloud ajouté. Les téléchargements
de modèles exigent une connexion initiale.
