# Living Memory V1.1 — extension modulaire

## Travail effectué

Poursuite de la branche existante `work/living-memory-v1.1-auto-memory` depuis `89de7bd6`, sans réinitialisation du projet, sans modification de main ni de la branche V1. L'extraction automatique, la revue des souvenirs et le stockage versionné déjà présents sont conservés.

Ajouts :

- Architecture maître, contrats des futurs modules et feuille de route ; aucun outil externe, service autonome ou chargeur de code ajouté.
- Migration SQLite additive 2 -> 3 -> 4 : scopes projet/monde, FTS5 des sources, archives de conversations et décisions, checkpoints persistants. Les anciens documents gardent leur projet Général par défaut.
- ContextLifecycleManager : estimation conservatrice par octets UTF-8, seuil de compaction à 75 %, résumés extractifs privilégiant les décisions explicitement marquées, checkpoints et restauration. Les messages entiers restent dans l'archive si leur extrait ne rentre pas dans le budget. Le contrôle exact de place du runtime demeure actif avant génération.
- ReliabilityEngine : classement hybride vectoriel/FTS5 et décisions utilisateur attribuées. Les questions et réponses IA archivées ne sont pas des preuves RAG. Une absence de référence utilisable entraîne l'abstention ; la sortie est tamponnée avant affichage.
- Natures explicites observation, déclaration, hypothèse et déduction ; aucun statut vérifié contrôlé par le modèle. Archivage versionné d'un souvenir avec conservation de sa source.
- Centre de mémoire : sélection du projet, revue des souvenirs et provenance, corrections/suppressions/archivage, sessions originales, marquage des décisions, résumés et contrôles de compaction/reset. Les widgets réutilisent le thème Flutter existant.

## Résultats de validation

Les exécutions et leur état sont consignés dans EXECUTION_LEDGER.md. Le résultat final de la suite complète, de l'analyse et de l'APK doit être renseigné après lecture des preuves Actions ; ce document ne constitue pas à lui seul une preuve de succès.

Les corpus des tests sont explicitement synthétiques. SQLite et FTS5 s'exécutent réellement sur les runners ; les doubles remplacent les modèles natifs. Les tests couvrent migration depuis V1/V2/V3, préservation et réouverture, scope des recherches, déduplication, provenance, contradictions potentielles préexistantes, compaction/reset/restauration, archivage et abstention structurelle. Les widgets de sessions sont testés en petit écran et largeur paysage avec texte agrandi et thème sombre.

Une revue indépendante en lecture seule a identifié un défaut de déduplication entre projets, reproduit par test avant correction. Elle n'a exécuté aucun test Flutter ; la CI est la preuve d'exécution.

## Limites et travaux futurs

- Le contrôle des citations n'est pas un vérificateur logique. Une réponse peut citer une source sans en découler ; aucun pourcentage de réduction des hallucinations n'est revendiqué. La qualité sémantique et la résistance réelle aux injections restent à mesurer avec les modèles sur le téléphone.
- La séparation des sources par agent/projet/monde est appliquée avant classement. Le namespace utilisateur des contrats ne remplace pas une authentification ; l'application V1.1 est locale et mono-utilisateur. Aucune API externe n'est exposée.
- Les archives et les documents sont indépendants. Archiver un souvenir ne masque pas son document d'origine. Le reset ne purge aucune donnée permanente. La recherche dans les conversations ne reprend que les décisions utilisateur marquées, toujours attribuées et non vérifiées.
- La génération reste une réponse RAG neuve à chaque question. Les archives/checkpoints servent à retrouver les décisions et préparer le futur dialogue agent ; les anciennes réponses IA ne sont pas réinjectées automatiquement comme contexte fiable.
- Pas d'export/restauration utilisateur complet, de chiffrement applicatif, d'OCR, de service Android permanent ni d'agent autonome exécutant des outils. Les contrats correspondants préparent ces extensions, sans les simuler.
- Inférences séquentielles et limites de données conservées ; la résidence simultanée des poids, la RAM maximale, la température, l'autonomie, le sélecteur Android, les inférences réelles et le mode avion n'ont pas été testés sur S22.
- La signature Android debug peut empêcher une mise à jour conservant V1. Ne pas désinstaller V1 pour contourner un refus de certificat. Voir S22_VALIDATION_CHECKLIST.md.

## Sources officielles

- https://www.sqlite.org/fts5.html
- https://developer.android.com/develop/background-work/background-tasks
- https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/long-running
- https://developers.google.com/edge/litert-lm/models/gemma-4
- https://ai.google.dev/gemma/docs/embeddinggemma/model_card_2

Les modèles et profils déjà configurés sont réutilisés ; aucune nouvelle API IA payante ni dépense ajoutée.
