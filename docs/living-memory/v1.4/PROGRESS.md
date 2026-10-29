# Living Memory V1.4 — journal et feuille de route

Statut courant : mission logicielle V1.4 livrée et vérifiée en CI ; APK ARM64 expérimental disponible. Essais matériels S22 non exécutés.
Les entrées ci-dessous conservent les résultats observés à chaque étape, sans attribuer les preuves V1.3.1 à V1.4.

## Reprise sans recréation

- Source vérifiée : `32dfa547bf3ff63eec6fa5025c7641db45fc858e`.
- Branche cible créée depuis ce SHA : `work/living-memory-v1.4-extensions`.
- Code construit V1.3.1 : `f73a8e13c72173362630648513ffe81020b0e727`.
- Run historique `40654444799` relu via GitHub : completed/success, head SHA concordant.
- Aucun AGENTS.md trouvé dans l'arbre source inspecté.
- Documents lus une fois : rapports V1.3.1 AUDIT, REPORT, REVIEW, SIGNING, STORAGE ;
  CURRENT_STATE, ARCHITECTURE_MASTER_PLAN, LIVING_WORLD_ARCHITECTURE.
- Modules examinés : contrats, MemoryStore, sessions, ReliabilityEngine,
  MultiModelEngine, ouverture MemoryScreen, EmbedderService, SkillStoreService,
  SkillRepository et SkillCatalog ; réutilisation prévue, pas de remplacement global.
- Le dépôt Living World AI séparé n'a pas été identifié dans les recherches accessibles.
- Aucun audit de dépendances global répété ; lockfiles et code produit inchangés.

## Vérifications réellement exécutées au cadrage

Depuis la racine du dépôt :

```sh
python -m unittest discover -s samples/litert/flutter/tool -p test_apk_signer.py -v
python -m unittest discover -s samples/litert/flutter/tool -p test_native_dependency_security.py -v
python -m unittest discover -s samples/litert/flutter/tool -p test_android_security.py -v
```

Résultats : 5 + 3 + 4 = **12 tests réussis**, zéro échec. Les quatre contrôles
Android portent ici sur les sources, pas sur un nouveau manifeste fusionné.
Le parseur de signature ne constitue pas une validation d'un nouvel APK.
Pas de Flutter/Dart disponible sur PATH au cadrage ; aucune exécution locale
Flutter effectuée. Les 3 060 tests/15 ignorés consignés dans le rapport V1.3.1
ne sont pas attribués à V1.4. Aucun appareil utilisé.

## Phases et conditions de poursuite

- [x] 1. Vérifier dépôt/source/run, lire audits réutilisables et repérer les modules.
- [x] 2. Revoir et approuver la [spécification proposée](../../superpowers/specs/2026-10-28-living-memory-v1.4-design.md).
- [x] 3. Plan `writing-plans` écrit ; poursuite autorisée par Tivini sans nouvelle validation des choix couverts.
- [x] 4. TDD : migration additive et adaptateur mémoire/monde intégré.
- [x] 5. TDD : politique de permissions, outils, Skills existants, plugins et MCP.
- [x] 6. TDD : missions, file persistante, annulation et reprise explicite.
- [x] 7. Tester deux agents, souvenirs privés, publications et reopen SQLCipher.
- [x] 8. Préparer export/restauration et signature stable ; protocole de préservation (certificat à comparer avant installation).
- [x] 9. Revue indépendante, corrections, régressions, analyse et compilation APK ARM64.
- [x] 10. Rapport de preuves au commit exact, artefacts, limites et protocole S22.

## Skills et contrôle de progression

Skills installés lus : using-superpowers, brainstorming, writing-plans,
test-driven-development, requesting-code-review, verification-before-completion.
Brainstorming appliqué au cadrage architectural. Les autres étapes ne sont pas
déclarées exécutées parce que leurs instructions ont seulement été lues.
Graphify consulté ; pas de graphe existant dans l'arbre inspecté, pas de graphe
généré ni d'extraction payante. Cartographie factuelle par fichiers existants.

Le skill brainstorming exige la revue de la spécification écrite puis celle du
plan avant implémentation. L'autorisation de mission est conservée ; cette revue
porte sur les choix techniques concrets. Aucun verrou technique n'empêche la
lecture du dépôt ou la publication de ces documents.

À chaque phase : enregistrer SHA, commandes, codes de sortie, limites et liens
vers preuves ; commit distinct après validation. Relire seulement le diff et les
documents affectés. Aucun changement de branche stable, aucun service payant
provisionné, aucun secret demandé ou ajouté.

## Reprise L0/L1 et plan validé

- CDC V1.0 retrouvé : libfile_c2f7c74c670881919ab80056bdbe9a94, 17 pages ; texte consulté.
- Dossier L0 : libfile_84f2200fe3908191a8f9fb81b7fc95e8 ; sections audit/architecture et contrat L2 consultées. Plan L1 et spécification retrouvés dans Git, non recréés.
- L1 source `5ca4ae5b08c5da6545276b252e39fdbf675430fe`, merge canonique GitHub `7687f388d7ab774611c8829e32dc1593f432c7f0` ; aucun changement sur la branche L1.
- Plan : docs/superpowers/plans/2026-10-28-living-memory-v1.4.md ; commit tests/plan `e87f610ed12658097bf5d41645776a6c4840f417`.
- Trois tests Python de frontières L1 réexécutés : succès. Aucun SDK Flutter/Dart installé ; téléchargements publics ciblés indisponibles ici. Aucun lancement Flutter local ni contournement des protections réseau.
- CI TDD initiale : run 40755565977, statut en cours au moment de cette entrée ; aucun résultat anticipé.
- Ruling: extraction canonique en package et adaptateur séparé contre MemoryPort L1 — exigence de modularité confirmée par CDC/L0 et réserves de Tivini — coût si erreur : reprendre les exports et adaptateurs, sans duplication du store.
- Ruling: initialement héberger le raccordement dans Living Memory avec un espace monde distinct ; observateur Android L1 conservé — ne pas partager une base entre deux applications ni copier les moteurs — coût si erreur : packaging d'un second hôte, pas réécriture des moteurs.
- Ruling: aucune nouvelle validation du plan demandée — autorisation explicite de Tivini — décisions majeures hors spécification restent soumises à accord.

### Première preuve rouge
Run40755565977 / job123053428142 terminé en échec attendu : dépendances historiques préparées avec succès, quatre fichiers de tests ne compilent pas car les nouveaux packages sont absents. Aucun test comportemental passé à ce stade. Artifact12846011328 conserve les quatre journaux. Ce rouge prouve l'absence des modules, pas encore la qualité des futures assertions.

### Intégration et revue intermédiaire

- Commits canoniques : 5e3dcca (extraction/transfert), 3d48b23 (adaptateur monde), 6812625 (extensions), a070984 (contraintes crypto et test effacement), a5a0537 (correctifs transaction/FK et régressions de revue).
- Run40756678616 : échec du solveur, cause identifiée crypto3.0.6 épinglé dans trois modules L1 ; contraintes compatibles ^3.0.6, version applicative3.0.7 conservée.
- Run40757101294 : export13/13 et extensions14/14 verts ; échecs reproduits suppression de mission et transaction imbriquée monde ; UI absente rouge attendue. Aucune validation finale annoncée.
- Pubspec.lock applicatif généré par CI importé : uniquement huit dépendances path ajoutées, aucun changement de version externe par rapport à V1.3.1.
- Revue indépendante T1–T4 : six constats importants, tracés dans REVIEW.md. Les nouvelles régressions couvrent schéma incomplet, callbacks dépassant le délai et courses entre adaptateurs.
- L'hôte monde réutilise WorldFactory/WorldCore/SimulationRunner/CheckpointStore/WorldViewport L1 ; pas de règles ni carte réécrites. Il bloque l'avance tant que le checkpoint courant n'est pas acquitté par la mémoire.

### Revue et preuves ciblées suivantes

- Run40759820726 : sauvegarde20/20, extensions16/16, extraction2/2, migrations1/1 et fiabilité7/7 verts. Le test nouvellement ajouté de rôle query était rouge ; corrigé par embedQuery distinct en fd12d729.
- Run40811435881 / fd12d729 : adaptateur World8/8, extraction2/2, migrations1/1 et fiabilité7/7 verts. Reproductions rouges : trigger/vue inattendus acceptés (20pass2fail), espaces vides transformés en noms réservés (extensions16pass1fail et widget). UI World : assertion de confirmation privée encore à diagnostiquer.
- Corrections suivantes : allowlist du schéma SQL canonique et postcondition missions désactivées ; espaces bruts vides/Unicode conservés ; retrait d'une assertion non-null superflue signalée par analyse.
- Contrôles locaux : frontières World3tests, sécurité native/source7tests, signature5tests passent. Flutter reste vérifié exclusivement en CI avec SDK épinglé.
- Aucun résultat APK ni matériel acquis à ce stade. Le parcours SAF du plan est en cours de raccordement ; aucune activation destructrice d'une base restaurée.

### Preuves L1 et régressions finales

- Run40812031178 /7b128f2d : sauvegarde22/22, extensions17/17, extraction2/2,
  World8/8, migrations1/1 et fiabilité7/7 verts. Le widget extensions passe.
- Suites L1 réutilisées : contracts8, core23, runtime8, persistence8,
  observateur10, headless16 ; analyses et frontières passent.
- Scénario10000ticks : invariants=true, SHA256
  05e332f0c6b5f5b4c1950ef0fe769f98d65c1f8550090ca152272782536acde5.
- UI World : la nouvelle assertion SQLite confirme un reçu écrit ; seul le texte
  de confirmation sortait de la ListView construite. Le test défile maintenant
  vers le résultat au lieu de supposer sa présence dans le viewport.
- SAF : rouge réel fichiers service/panel absents dans ce run ;8tests initiaux.
  Implémentation ajoutée ensuite, gates source natifs4/4. Un9e test reproduit
  les alias des chemins OS Android avant correction du service.
- Revue fraîche : droits de partage persistants à neutraliser lors de restore ;
  nouveau test export/restore World publié avant correction. Sources et reçus
  doivent rester, source active inchangée, réapprobation explicite nécessaire.

### Derniers rouges et correctifs de revue

Run40813104637 /2d7a9bbe : UI World et extensions2/2 verts ; sauvegarde22/22,
extensions17/17, extraction2/2, migrations1/1, fiabilité7/7 restent verts.
SAF7/9 : alias OS rouge attendu et assertion clipboard trop large (uniquement
hasStrings interrogé par Flutter, pas d'écriture). World8/9 : restauration rend
encore le partage actif, rouge sécurité confirmé. SuitesL1 et10000ticks verts.

Correctifs en validation : racine de source hôte canonique ; autorisations
persistantes sous namespace réservé permission.* supprimées uniquement dans la
copie restaurée. Core sans import World/Flutter ; source active, souvenirs et
reçus de provenance conservés. Le test exige une nouvelle publication pour B.
Branches revérifiées : main0f95b7eb, source32dfa547 et World5ca4ae5b inchangés.

### Modules verts et lancement de validation finale

Run40813983620 /e06e251f : backup22, extensions17, extraction2, transfert9,
World9 (y compris réapprobation après restore), migration1 et fiabilité7 verts.
Analyse Flutter sans issue ; analyses des3packages extraits et suitesL1 vertes.
UI World passe ; l'unique assertion restante lit une sortie de page lazy après
chargement du vrai Skill/JSON embarqué, corrigée par défilement explicite.
Aucune donnée ou assertion fonctionnelle supprimée. Format officiel CI appliqué.

La chaîne APK V1.4 est activée ensuite sur la branche isolée : elle impose
sécurité réutilisée, suite mémoire, format/analyse et suite Flutter complète
avant compilation ; contrôle applicationId/version6/1.4.0, ABI et signature.
Aucun succès APK anticipé. Aucun appareil ou simulateur utilisé.

### Régression historique d'interface reproduite

Run APK40814704409 /45e395a : contrats sécuritéV1.3.1 verts (2,8,6,4,74),
mais suite mémoire203pass5fail. Les5échecs sont les3cas assistant_screen et
2cas cancellation : journaux hit-test montrent les cibles Discuter/Gemma à
y608 hors viewport600 après ajout des entréesV1.4. Aucune compilation ni APK
produit. Correction ciblée des tests : stabiliser le clavier après saisie et
rendre le défilement effectif par frame avant clic. Assertions de conversations,
isolation, sauvegarde explicite et annulation conservées intégralement.

### Régressions complètes et métadonnées

Run40815219600 /3075ad34 : les5tests historiques corrigés et la suite mémoire
208/208 passent. Format et analyse sans issue. Suite Flutter complète :
3120 réussis,15ignorés,1échec : build_info_test attend1.4.0+6 du pubspec mais
kAppVersion indiquait encore1.3.1+5. Constante de diagnostic alignée ; assertion
historique conservée. Aucun APK produit par ce run, compilation correctement
bloquée. Contrats V1.4/L1 du même commit : run40815219604 entièrement vert.

### Clôture vérifiée — source a569a2cb

- Contrats40859640417 : succès ;61tests V1.4,69avec migration/fiabilité,
  73tests L1, frontières et analyses verts. Headless10000ticks invariants=true,
  même SHA05e332f0c6b5f5b4c1950ef0fe769f98d65c1f8550090ca152272782536acde5.
- APK40859640335 : succès ;3121tests Flutter,15ignorés ;208tests mémoire/LLM,
  format sans diff et analyse sans issue. Contrôles sécurité/source et manifeste
  fusionné passent ; build release ARM64, signaturev2 et contenu vérifiés.
- APK901797479octets, SHA415a197ad441206386a3aa83426e1f4f0cbb4a6a00c13df73e549dbd76a5c5c4.
  Artefact12892006101 ; preuves légères12891921392 ; détails dans BUILD.json.
- Signature debug expérimentale, pas de clé stable créée ; certificat
  587abca8a6ab1af2cff0ab641a3f29f15a22f604e70be02240b15e5326399e0f.
  Comparaison avec installation requise ; aucune désinstallation conseillée.
- Revue finale sans défaut important/critique restant confirmé. Point mineur,
  restrictions fonctionnelles et limites matérielles consignés dans REPORT.
- État de référence CURRENT_STATE mis à jour pour reprise courte. Dernière
  publication documentaire seulement ; source compilée et testée inchangée.
- Branche isolée conservée selon la demande ; aucun merge stable ni nettoyage
  destructif du workspace. Aucun appareil utilisé ou service payant provisionné.
