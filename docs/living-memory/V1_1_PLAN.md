# V1.1 — conception et plan d’exécution

Base : 0f95b7eb, branche V1 conservée. Exécution native selon la mission autorisée.

## Décisions
- Étendre le fichier privé living-memory-v1.db par migration additive transactionnelle ; préserver documents, agents et vecteurs V1. Refuser une version future.
- Extraction uniquement sur passages de sources importées et notes, jamais depuis une réponse IA ni une question. Désactivée par défaut, réglage par agent.
- Réutiliser ConversationRepository/Gemma et EmbedderService/EmbeddingGemma, sans nouveau moteur, API ou tâche en arrière-plan.
- Chaque candidat doit être une citation exacte du passage ; modèle, horodatage, source, page, agent, nature observation/déduction, incertitude et statut sont conservés. Une citation est un contrôle de provenance, pas une validation du monde réel.
- Rejeter les JSON incorrects et citations inventées. Aucun statut vérifié produit par le modèle. Confirmation explicite de l’utilisateur seulement.
- Similarité cosinus sur un curseur SQLite borné : suggestions de liens, jamais fusion sémantique automatique. Doublon exact du même passage idempotent. Contradictions potentielles signalées sur une même clé sujet/relation ; pas de résolution automatique.
- Correction versionnée avec ancien contenu conservé et vecteur recalculé ; suppression physique des souvenirs, révisions et liens. Suppression d’une source purge ses souvenirs.
- Limiter à 8 passages par import automatique, 3 candidats par passage, 700 octets par passage, 6000 octets de sortie et 1000 souvenirs par agent. Import V1 conservé si extraction échoue. Retraitement explicite des sources existantes.

## Petites étapes vérifiables
1. Tests stockage/migration depuis une vraie base V1 : conservation, fermeture/réouverture, profils incompatibles, isolation agents, idempotence, liens, correction, suppression.
2. Stockage additif et modèle candidat strict, tests de sorties malformées et provenance.
3. Adaptateur Gemma local et orchestrateur séquentiel annulable ; tests avec ports simulés uniquement pour inférences, SQLite réel.
4. UI : réglage persistant par agent, liste, provenance, confirmation, correction, suppression, consolidation par liens consultables ; tests widget.
5. Suite Flutter complète, analyse et build Actions arm64 ; corriger sur preuves. Rapport final avec résultats observés et limites appareil.

## Points de revue
Citation exacte mais affirmation fausse ; prompt injection dans source ; ambiguïté/négation ; échec après import ; destruction de source ; changement agent ; arrêt pendant génération ; doublons concurrents et profil d’embedding.

## Limites attendues
Pas de test matériel S22 dans ce runner : qualité des modèles réels, installation, mémoire maximale, latence, batterie, chauffe, mode avion à vérifier sur téléphone. Pas de validation universelle des faits ni de fusion de paraphrases prétendument certaine.

## Journal
- Audit structurel Graphify local : 3 fichiers V1, 86 nœuds / 89 relations, sans service LLM externe. Lecture manuelle du stockage, écran, import natif, contrats de conversation/embeddings, configuration modèles, workflows et tests V1.
- Environnement local sans Flutter/Dart. Tentatives de récupération du SDK par URL officielle : 404 ; validation exécutable confiée à Actions, pas à une imitation Python.
- Branche GitHub créée exactement depuis 0f95b7eb. Écriture distante via connecteur GitHub (push CLI sans identité d’authentification).
- Ruling : les limites d’extraction s’appliquent par action, avec point de reprise SQLite ; les documents V1 peuvent être retraités à la demande. Aucun échec d’extraction ne doit annuler un import V1 terminé.
- Actions 40475389810 : contrôle rouge, API nouvelle absente (analyse). Actions 40475869427 : 29 tests ciblés réussis ; échec de chargement de l’UI attendue, pas encore livrée. Moteur testé avec SQLite réel et vecteurs synthétiques ; aucun résultat d’inférence réelle revendiqué.

- Ruling : recherche des souvenirs confirmés explicitement dans le RAG, avec attribution et mention de l’absence de vérification externe. Les corrections réindexées seraient sinon ignorées par le parcours V1. Les candidats non confirmés n’entrent pas dans cette recherche.
- Régressions Actions 40476641376 : absence de searchMemories/callback d’annulation, et deux tests widget reproduisent une génération après Arrêter (ouverture et vérification de contexte).

- Actions 40477062946 : 34 tests ciblés réussis, un test de correction révèle l’usage d’un TextEditingController déjà libéré pendant la fermeture du dialogue. Cause reproduite ; nouveau MemoryTextDialog propriétaire de son contrôleur, réutilisé pour notes/agents V1 et corrections V1.1.
- Revue de suivi : annulations et recherche confirmée validées par inspection ; étiquette des corrections clarifiée.

- Actions 40477380809 : les 35 tests ciblés passent ; analyse bloquée uniquement par un import typed_data redondant dans le nouveau test d’annulation. Import retiré, format Dart appliqué depuis la preuve CI. La CI contrôle désormais le format sans réécrire le code testé.

- Actions 40477834391 : format et analyse sans problème ; suite complète 2965 réussis / 15 ignorés / 1 échec, test existant config/build_info_test.dart. Cause : version pubspec passée à 1.1.0+2 mais constante kAppVersion restée à 1.0.0+1. Constante alignée sans modifier le test. Preuves légères séparées de l’archive APK pour permettre leur inspection sans télécharger 900 Mo.

- Source finale testée 89de7bd6 : 35 tests ciblés, analyse propre, suite complète 2966 réussis / 15 ignorés (Actions 40478470088). Le build a été annulé après l’arrivée de commits concurrents 6d35d101 et 386d733f sur la même branche, pas après un échec de tests. Ces ajouts sont conservés.
- Livraison isolée work/living-memory-v1.1-apk, base exacte 89de7bd6, workflow dédié : comparaison Git des fichiers samples/litert/flutter avant build. Pas de nouvelle exécution des tests d’une source identique ; les preuves de la suite précédente sont référencées explicitement.

- Packaging 40480260704 : APK produit, script de certificat échoué à cause du nouveau préfixe apksigner V2 Signer. Regex corrigée et vérification indépendante sur l’artefact existant 40482049625 réussie : hash, v2, arm64 et modèle. Certificat différent de V1, mise à jour directe bloquée ; aucune désinstallation recommandée.
- Rapport final et guide téléphone conservés sur la branche de livraison figée, sans écraser le chantier parallèle sur la branche demandée. Aucun merge.
