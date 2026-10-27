# Plan : ARCHITECTURE_MASTER_PLAN.md

Reprise autorisée sur branche dédiée existante, pas de fusion. Audit et plan commis avec tests avant implémentation (6d35d101). Vérification de référence 40478470088 : format, ciblés, analyse et suite complète réussis ; build annulé par concurrence après notre nouveau commit. Ne pas attribuer un APK à cette exécution.

Décision : validation exécutable sur runners Actions puisque Flutter/Dart local absents. Les sorties complètes sont des artefacts CI. Tests nouveaux lancés avant code ; conserver l'échec attendu (API absente) dans le rapport. Le formatage CI produit un patch consultable et reste bloquant.

Précontrôle : ContextLifecycleManager dépend des archives MemoryStore et de MemoryScope ; ReliabilityEngine dépend de searchText et du classement V1. Ordre : migration/ports, services, UI, validation. Les ports des futurs services ne rendent aucun service actif.

CI 40479866803 : arrêt au format avant tests. Ce n'est pas une preuve comportementale ; ordre de contrôles corrigé dans 386d733f. Attendre les contrats exécutés avant l'implémentation.

CI rouge 40479936350 : 35 tests ciblés existants réussis ; chargement impossible des deux nouveaux modules absents (ReliabilityEngine, ContextLifecycleManager et archiveMemory). Implémentation démarrée après lecture des erreurs. Les nouveaux tests UI et projet ajoutés ensuite seront validés dans l'exécution suivante ; ils n'ont pas encore une preuve rouge individuelle.

Implémentation c125f14a : migration 3, FTS5 externe et triggers, sessions et checkpoints, scopes de documents projet/monde, UI de sessions, archivage versionné et abstention structurelle. Le texte généré est tamponné avant contrôle ; l'archive garde son origine IA non vérifiée. Aucun service autonome lancé.

CI c125f14a / 40480927925 : 42 tests ciblés réussis ; test d'écran non chargé, variable vector absente. Cause : remplacement du bloc de recherche trop large ayant enlevé l'appel existant à embedQuery. Appel et contrôle d'annulation restaurés. Aucun problème SQLite ni widget de sessions signalé dans cette exécution. Ajout de régressions pour compaction après reset et nouvelles catégories avant correction ; tests migration V2 et séparation projet étendus.

Revue locale : l'idempotence des checkpoints par (session,ordinal,type) rendait une nouvelle compaction après reset inopérante et ignorait les décisions marquées ensuite. Régression ajoutée avant correction. Les catégories déclaration/hypothèse doivent être explicites plutôt que fondues dans observation/inférence : test ajouté. Décision : indexer séparément les archives, mais n'autoriser en RAG que les décisions explicitement marquées par l'utilisateur, attribuées comme non vérifiées ; ni questions ni réponses générées ne deviennent des preuves.
