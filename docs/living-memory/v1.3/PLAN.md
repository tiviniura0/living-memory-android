# Living Memory V1.3 — plan et contrat d’intégration

Référence : docs/living-memory-google-integration-correction.md.
Base : f8f87666 ; runtime V1.2 : 376ccf33353ec101b1c424b6121eb69ecfc55f62.

Objectif : raccorder les services Google existants à la mémoire locale, sans
réécriture, changement de schéma SQLite ni fusion stable. Exécution dans la
session autorisée par la mission. Une réponse libre ou une description visuelle
n’est jamais présentée comme un fait vérifié et n’est pas mémorisée implicitement.

## Architecture retenue
Conserver le parcours RAG strict existant. Ajouter des actions explicites chat,
rédaction et analyse d’image dans la route mémoire, en utilisant le même verrou
et le même moteur E2B/E4B. Chaque génération ouvre une conversation neuve pour
éviter un historique partagé entre agents. Réutiliser ImageRepository pour la
sélection et normalisation, SpeechRepository pour STT/TTS et AudioRepository
pour capture/lecture. Les imports de transcriptions/descriptions sont explicites,
avec provenance et catégorie distinctes, jamais une vérification externe.
Conserver MemoryScope et les ports Living World AI indépendants de l’UI.

## Travaux et validation
- [ ] 1. Baseline : reconstruire et tester le code V1.2 inchangé via Actions,
      conserver les identifiants des artefacts et preuves de signature/hash.
- [ ] 2. Intégration : tests d’abord pour isolation, annulation, refus image
      incompatible, absence de réponse incomplète, provenance ; implémentation
      via les services existants ; tests ciblés puis suite complète.
- [ ] 3. Gestion des modèles : vérifier téléchargement/import/hash/annulation,
      ajouter suppression explicite du registre sans supprimer le fichier
      d’origine ni les autres modèles. Tester persistance et confinement.
- [ ] 4. Sécurité : permissions, composants, sauvegardes, réseau, logs,
      dépendances verrouillées, licences ; automatiser les contrôles possibles.
- [ ] 5. Revue indépendante, correction des problèmes importants, analyse et
      tests complets, build ARM64, contrôle de l’APK et des preuves Actions.
- [ ] 6. Rapport factuel, installation prudente et protocole S22 : aucun essai
      matériel revendiqué sans téléphone, aucun chiffre RAM/température inventé.

## Points de revue
Annulation pendant ouverture/fit/STT ; changement d’agent/projet ; fin de flux
sans événement terminal ; modèle sans encodeur image ; erreurs de libération
native ; refus micro ; fermeture de route pendant une capture ; suppression
sans effacement d’un chemin externe ; données conservées si signature différente.

## Journal
- Dépôt cloné sur la branche dédiée ; aucun AGENTS.md trouvé.
- Artefacts baseline existants : run 40579317895, APK 12769962723,
  preuves légères 12770606152 ; run vérifié completed/success via API GitHub.
- SDK Flutter absent initialement ; récupération du tag épinglé 3.47.3.
- Graphify absent : cartographie par lectures, rg et tests ; pas de graphe inventé.

- Tests rouges observés dans les journaux Actions : 40633680412 (AssistantSession
  absent et remove absent), 40633822012 (MemorySpeech absent ; correction d’un
  nom erroné de fake RecordingSynth dans le test), 40634189333 (bouton Discuter
  absent), 40634641194 (contrats stockage/langue/WAV absents).
- Contrôle Python Android : usesCleartextTraffic absent → échec constaté, puis
  propriété false → 3 tests verts ; ajout du contrôle debuggable ensuite.
- Mise en œuvre native SAF WAV bornée ; validation appareil non exécutée.
- Revue baseline indépendante : copies de modèles non bornées corrigées ;
  conservation des copies de réponses en sessions documentée ; téléchargements
  HTTPS choisis par utilisateur conservés (pas de liste blanche d’hôtes).

- Revue de l’intégration indépendante : interruption OS non écoutée et WAV
  tronqué toléré par le décodeur partagé. Tests ajoutés avant correction : run
  40635699791 montre exactement quatre échecs comportementaux (123 autres
  tests ciblés passent), analyse sans problème. Correction : abonnement aux
  interruptions, arrêt/drainage avant réutilisation, validation stricte des blocs
  WAV à l’import seulement. Le décodeur Google partagé reste inchangé.
- Continuité de session : run 40635905050 constate l’absence du marqueur de
  la session courante dans le prompt. Réutilisation du ContextLifecycleManager
  existant, six messages récents bornés, respect des checkpoints et du scope.
- Audit Maven baseline : deux avis OSV ; contraintes ciblées Guava/OkHttp et
  contrôle des versions résolues, sans mise à jour générale des dépendances.

- Run 40636347827 : 126 tests ciblés passent, dont les quatre régressions audio ;
  seul échec = recherche du dropdown non construit hors écran dans le test widget.
  Correction du scroll de test vers la ListView externe ; assertions conservées.
- Badging baseline : READ/WRITE_EXTERNAL_STORAGE transitives identifiées puis
  retirées via fusion Android ; gate testé rouge sur ces permissions, vert sur
  le source corrigé. Les composants WorkManager protégés par permission système
  sont autorisés explicitement. Validation du manifeste final en CI.

- Revue du nouveau rappel de session : la compaction de navigation V1.2 peut
  inclure les archives d’avant reset. Deux tests UI rouges (reset immédiat puis
  compaction, et messages ultérieurs puis compaction) : run 40636987109.
- Décision : préserver la compaction/navigation et les décisions explicites
  V1.2 (test existant qui marque une ancienne décision après reset). Le nouveau
  rappel d’inférence ignore les résumés d’archive dès qu’un reset existe et ne
  reprend que les messages postérieurs au dernier reset. Archives intactes.
  Coût : après reset, le rappel conversationnel se limite aux messages récents ;
  les documents et décisions permanentes restent accessibles par le RAG.

- Première compilation V1.3 ARM64 réussie (40636706468), puis contrôle fusionné
  refusant UIDTJobService du téléchargeur existant. Le manifeste réel confirme
  sa permission système BIND_JOB_SERVICE ; les autres exports sont le launcher,
  WorkManager BIND_JOB_SERVICE et deux receivers DUMP. Correction du gate par
  liste exacte de ces composants et permissions, sans relâcher le manifeste.
- Versions natives réellement résolues : Guava 33.7.2-android et OkHttp 4.9.2 ;
  aucune permission READ/WRITE/MANAGE_EXTERNAL_STORAGE dans le manifeste fusionné.
