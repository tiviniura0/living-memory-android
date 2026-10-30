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

## Reprise tâche 1 — 30 octobre 2026

Base réelle : 994675132ba7ddf52965eece193faaee5f6ae536, descendant du prérequis 4801903.
Ruling: la mission actuelle autorise les modifications de la tâche 1 et leur push sur la seule branche Godot ; la restriction historique au seul fichier workflow concernait la préparation.
Ruling: utiliser la bibliothèque x86_64 officielle du même AAR 4.5.1 sur émulateur x86_64 pour le RED/GREEN natif ; conserver ARM64 seul pour l'APK livré. Cela permet le TDD sans téléphone, mais ne remplace pas la recette ARM64/S22.
Pre-flight: T1 fournit la vue/canaux aux T4/T5/T6 ; aucun payload de simulation ni boucle Godot en T1. T2/T3/T4 restent hors de cette mission.
Test de non-destruction de la coque Android : RED constaté (Gradle remplacé par `overwritten`), puis GREEN après copie des seuls fichiers manquants. Squelette compilable du host et quatre tests natifs ajoutés pour observer l'absence réelle de ready sur émulateur ; aucune implémentation Godot encore écrite.

Conditionnement APK : quatre assertions RED observées sur squelette appelable, puis GREEN (8 tests Python au total). Inspection ARM64/PCK/libgodot et empreintes ; aucune exécution native déduite de ces tests ZIP.
Premier CI tâche 1 (54d62def, run 41099396645) : 10 tests Flutter observateur réussis, analyse sans issue, APK x86_64 compilé. Instrumentation non lancée : conflit de résolution runner AndroidX 1.6.2 contre 1.3.0 de Flutter integration_test. Correction ciblée au commit 576b093 : versions alignées en debugImplementation et androidTestImplementation, sans effet sur release. Aucun RED natif revendiqué pour cet échec.

RED natif effectivement observé sur émulateur API 35/x86_64 : run 41100676008, commit ca86a539, artefact 12998123628. Les quatre tests compilent et échouent chacun par `No real Godot ready event within 20 seconds`. Aucun échec de compilation n'est utilisé comme RED. Les trois tests Flutter de canaux avaient échoué par assertions sur appels/événements absents au run 41099591373.
Implémentation host GodotFragment / GodotRenderPlugin / scène smoke / export PCK écrite après ce RED. Le ready et l'écho viennent uniquement du GDScript.
Ruling: les méthodes d'instrumentation sont lancées dans des processus cibles séparés pour isoler leurs résultats. Le test reopenTwentyTimes conserve ses vingt ouvertures dans un seul processus et une seule Activity ; aucun reset ni effacement ne masque cette exigence.
Risque natif identifié dans les sources officielles 4.5.1 : GLSurfaceView.onDetachedFromWindow → requestExitAndWait → GodotRenderer.onRenderThreadExiting → GodotLib.ondestroy → _terminate. Le host refuse de réutiliser un moteur détruit et ne quitte jamais Flutter. Ce garde-fou ne satisfait pas les vingt réouvertures ; gate à établir par les tests réels.
