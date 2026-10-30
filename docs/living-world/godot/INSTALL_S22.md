# APK expérimental de l'hôte Godot — S22

Cet APK debug affiche une scène de test native. La carte isométrique et le raccordement de Living Memory ne sont pas inclus dans la tâche 1. Consulter d'abord [REPORT.md](REPORT.md) pour les limites et le SHA exact.

Le package autonome reste `com.tivini.livingworld`. Le package de Living Memory `com.google.ai.edge.examples.litert_edge_demos` et ses données n'ont pas été modifiés.

1. Télécharger uniquement l'artefact ARM64 dédié cité dans REPORT.md et comparer son empreinte à `arm64-apk.json` dans les preuves du même SHA.
2. La signature debug du runner peut différer d'une installation précédente de l'observateur. Si Android refuse une mise à jour pour signature incompatible, conserver l'installation existante ; ne pas la désinstaller pour contourner ce refus.
3. À un premier lancement autorisé sur le téléphone, relever la version réellement affichée et conserver une capture ou le code d'erreur visible.
4. La fermeture/réouverture et la recréation Android constituent des gates distincts. Le signalement `renderer_restart_required` ne valide pas ces gates.

Aucune installation ni commande ADB n'a été exécutée sur un S22 par cette mission. Les performances, la consommation, les comportements de surface sur ARM64 et la cohabitation avec un modèle chargé ne sont pas validés par la CI x86_64.
