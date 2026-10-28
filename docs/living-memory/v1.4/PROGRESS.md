# Living Memory V1.4 — journal et feuille de route

Statut : cadrage réalisé ; spécification proposée, en attente de revue.
Aucune fonctionnalité V1.4 ni nouvel APK livré à ce stade.

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
- [ ] 2. Revoir et approuver la [spécification proposée](../../superpowers/specs/2026-10-28-living-memory-v1.4-design.md).
- [ ] 3. Produire et faire revoir le plan d'implémentation `writing-plans`.
- [ ] 4. TDD : migration additive et adaptateur mémoire/monde intégré.
- [ ] 5. TDD : politique de permissions, outils, Skills existants, plugins et MCP.
- [ ] 6. TDD : missions, file persistante, annulation et reprise explicite.
- [ ] 7. Tester deux agents, souvenirs privés, publications et reopen SQLCipher.
- [ ] 8. Export/restauration et signature compatible ; protocole de préservation des installations.
- [ ] 9. Revue indépendante, corrections, régressions, analyse et compilation APK ARM64.
- [ ] 10. Rapport de preuves au commit exact, artefacts, limites et protocole S22.

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
