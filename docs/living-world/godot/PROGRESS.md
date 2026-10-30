# SDD ledger — plan: docs/superpowers/plans/2026-10-29-living-world-godot2d.md

## État de reprise

- Préparation GitHub Actions : complete au SHA 4801903664c75f5fc1c492bd701c8a311e02a20d, run 41036150448.
- Task 1 : in_progress — prérequis et API officielles examinés, empreintes conservées ; pas de host ni de scène implémentés.
- RED natif : blocked — flutter doctor de cette exécution ne voit aucun appareil Android. Tests natifs non écrits/non exécutés ; aucun RED n'est revendiqué.
- Task 1 : NOT complete. Tasks 2–7 : non commencées.
- Résultats, erreurs antérieures et liens : ACTIONS_PREPARATION.md.
- Valeurs vérifiées : DEPENDENCIES.md.

Ruling: le push est autorisé par le message utilisateur suivant la première préparation ; il est limité à la branche work/living-world-godot2d et au fichier .github/workflows/world-godot.yml. workflow_dispatch et garde native de branche conservés.
Ruling: le probe Gradle ne valide que la compatibilité binaire et les ABI. Pas d'annonce ready synthétique, pas de moteur simulé, pas d'annonce du fonctionnement sur téléphone.
Ruling: ne pas modifier la version candidate 4.5.1 silencieusement ; geler les valeurs observées pour la sonde et terminer l'évaluation de version en tâche 1 avant le host.
Ruling: aucun symbole manquant ou test non lancé ne remplace le RED natif demandé par le plan. Le défaut de cible ARM64 doit être résolu avant cette étape ; ne pas recommencer les téléchargements déjà validés.

## Prochaine opération concrète

Configurer une cible Android ARM64 accessible pour l'instrumentation, puis écrire/exécuter realGodotReadyHasEngineVersion, secondOwnerIsRejectedWithoutKillingFirst, reopenTwentyTimes, resizeAndRotateKeepsHostAlive avec le squelette compilable décrit par le plan.
Continuer ensuite GodotFragment/FlutterFragmentActivity, PCK et build hôte, en respectant les étapes RED/GREEN.
Conserver World L1, Living Memory V1.4, schémas, données et branches stables.
