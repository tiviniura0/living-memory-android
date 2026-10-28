# Living World L1 — preuves
Base : 376ccf33353ec101b1c424b6121eb69ecfc55f62. Branche isolée, aucune fusion.
T1 : 5 tests rouge puis 5 verts ; analyse Dart sans erreur.
Essais S22 : non exécutés. IA : aucune, règles locales uniquement.

T1–T6 réexécutés après les correctifs : contrats 7 tests, core 23, agents 8, persistence 8. Les tests initiaux ont des journaux rouge/vert ; la réserve orpheline et les IDs du journal plein ont des tests de régression rouge/vert dédiés.
T7 : run 40604865123 a exécuté 4 tests Flutter réussis et l'analyse Flutter sans problème avant annulation par le run suivant. Tests sélection et grande police ajoutés pour validation finale.
T8 : logique pure de lifecycle testée avec un vrai core et un dossier temporaire ; 2 échecs observés avant implémentation. Les tests de boucle bornée ont aussi échoué avant implémentation. Le premier test widget disque plein utilisait à tort l'horloge factice pour une IO réelle ; corrigé avec runAsync.
T9 : 10000 ticks, deux exécutions, invariants vrais, SHA état 05e332f0c6b5f5b4c1950ef0fe769f98d65c1f8550090ca152272782536acde5. Aucun temps ni RAM de ce serveur n'est présenté comme une mesure S22.
T10 : contrôle de frontières, 2 échecs sur stub puis 3 tests réussis, frontières réelles OK. APK et suites finales : consulter le run lié au SHA de livraison.
Matériel : R01–05, R13, R16–18, mode avion et essai 30 min sur S22 non exécutés ici. Les tests integration_test sont fournis et n'ont pas été lancés sur appareil.
Blocage local : le contrôle automatique a rejeté une commande de vérification Flutter qui contactait le service de métadonnées d'instance. Aucune nouvelle tentative ni contournement local ; Flutter est exécuté sur GitHub Actions. Aucun refus lié à Dart.

Après revue indépendante : quatre défauts importants corrigés par tests de régression. La session hôte pure Dart sérialise désormais l'import, le remplacement du core, la capture des snapshots et les écritures. Un export échoué ne retourne plus une ancienne sauvegarde ; le relèvement de plafond exige un accord explicite ; une action importée ne peut appartenir à deux agents. Dernière validation locale : contrats 8, core 23, agents 8, persistence 8, headless/hôte 14, soit 61 tests Dart réussis, analyses sans erreur. Python frontières : 3 réussis. Tests de signature Living Memory inchangés : 5 réussis.
Les journaux locaux rouge/vert sont conservés sous evidence/ ; les fichiers d'artefact CI portent le SHA réellement testé. Revue et défaut mineur différé : REVIEW.md.
