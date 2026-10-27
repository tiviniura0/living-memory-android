# Living Memory V1.2 — validation expérimentale

## Périmètre et provenance
Source V1.1 : fe9c0af4acc9a2fc28fcef0c38ee5638425c778d.
Branche : work/living-memory-v1.2-multimodel. Aucun changement de main ou V1.1.
Base V1.1 verte : https://github.com/tiviniura0/living-memory-android/actions/runs/40556412829
Test rouge E4B : https://github.com/tiviniura0/living-memory-android/actions/runs/40573302675
60 tests ciblés réussis, seul le nouveau test E4B échoue : le filtre de nom
V1.1 refuse E4B. Format et analyse de ce commit réussissent.
Les résultats V1.2 définitifs sont ceux du commit et du run indiqués dans
apk-metadata.json et les journaux joints. Ce rapport n'est pas une preuve de build.

## Implémentation
- Port LocalModelRuntime indépendant des modèles ; adaptateur concret LiteRT-LM
  réutilisant ModelRepository, ConversationRepository et ChatModelSwitcher.
- Registre local version 1 distinct, choix Auto/E2B/E4B persisté par remplacement
  atomique. Copies privées en flux avec SHA-256 ; pas de nettoyage automatique.
- Les plans de chargement sont temporaires : aucun remplacement des préférences
  du modèle V1.1, aucune suppression de ses fichiers. Les autres écrans gardent
  leur modèle enregistré ; le slot est marqué pending après libération.
- Auto : E2B pour extraction/simple ; E4B si >=4 passages, question >500 caractères
  ou termes explicites de comparaison, synthèse, contradiction, analyse,
  explication ou raisonnement. Un seul modèle enregistré suffit en mode Auto.
  Sélection manuelle manquante : erreur explicite.
- Déchargement avant et après chaque tâche (chaque lot d'extraction, pas chaque
  souvenir). Verrou partagé maintenu jusqu'à la fin de l'inférence. Pas de
  chargement simultané des deux générateurs. EmbeddingGemma reste indépendant.
- Contexte GPU/CPU plafonné à 2048 tokens ; contexte compilé NPU conservé.
  Outils désactivés, backend conservé.
  Modèles .litertlm seulement ; mêmes contrôles de bundle/backend existants.
- E4B en échec récupérable : nettoyage puis un seul essai E2B s'il est enregistré.
  Annulation et refus de libération native : aucun repli. Réponse partielle
  abandonnée ; passages retrouvés réinitialisés avant l'essai E2B.
- Provenance Auto-Memory porte le générateur réellement utilisé. Schéma SQLite 4,
  espace vectoriel 768, agents/projets, sources et migrations V1.1 conservés.
- Ports futurs ToolRegistry/AgentRuntime/Scheduler conservés, sans exécuteur
  automatique ni service en arrière-plan.

## Revue et corrections
Revue indépendante en lecture seule : quatre points concrets ont été corrigés.
1. Erreur native de fermeture autrefois masquée par _closeQuietly : déchargement
   strict et blocage des chargements si l'état natif devient inconnu.
2. Mode E4B explicite avec registre vide : erreur, jamais appel E2B silencieux.
3. E4B dans le parcours historique : provenance dérivée du modèle actif.
4. Bundle NPU : contexte compilé conservé au lieu de le plafonner.
Régressions ajoutées pour ces chemins, plus un test étroit de l'adaptateur réel
avec un handle natif simulé qui refuse de fermer. Ce test n'utilise pas un GPU.

## Tests et limites
Les tests moteur utilisent un runtime de test, sans poids IA. Le registre teste
un vrai système de fichiers temporaire avec de petits octets synthétiques.
Les tests de mémoire utilisent SQLite réel et des embeddings synthétiques.
Ces validations ne prouvent ni la qualité des sorties, ni la compatibilité E4B
avec le GPU du S22. Aucun téléphone n'est connecté dans cet environnement.
Pas de validation matérielle, de mesure de RAM libre, de température, de débit
ou de latence. La limite de 2048 tokens est une politique conservatrice, pas
une garantie d'absence de manque de mémoire. Les tours multimodales présents
dans le bundle suivent encore le comportement existant de LiteRT-LM.
Un OOM qui tue le processus ou un crash natif ne peut pas déclencher le repli Dart.
Les modèles des autres démonstrations peuvent aussi occuper des ressources ;
le moteur ne prétend pas libérer leurs allocations.
Le hash complet avant chaque chargement et le déchargement après chaque tâche
augmentent la latence ; mesurer avant de conserver un modèle résident.
Les copies complètes demandent de l'espace disque en plus des imports. Les
anciennes copies restent volontairement présentes ; pas de purge silencieuse.
Le libellé E2B/E4B affecté par l'utilisateur n'authentifie pas les poids.
Un registre corrompu est refusé sans écrasement ; la mémoire V1.1 reste accessible.

## Signature et données
L'applicationId et living-memory-v1.db restent identiques. Le certificat debug
Actions peut changer entre builds. Vérifier le certificat dans l'artefact.
NE PAS désinstaller une V1/V1.1 contenant des données pour contourner une erreur
« application non installée ». Aucun export/restauration existant ne permet de
promettre une migration entre signatures différentes. L'APK est expérimental,
installable sur installation vierge ; la mise à jour dépend du certificat.

## Sources techniques vérifiées
- https://developers.google.com/edge/litert-lm/models/gemma-4
- https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm
- Sources et dépendances épinglées de ce dépôt, sans mise à jour automatique.
