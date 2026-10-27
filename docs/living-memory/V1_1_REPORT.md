# Living Memory V1.1 — rapport expérimental

## Périmètre et préservation

Dépôt existant `tiviniura0/living-memory-android`. Branche de départ
`work/living-memory-local-rag`, commit `0f95b7eb0db759ed4a0071756c231c94e36f6c04`.
Travail isolé sur `work/living-memory-v1.1-auto-memory`. Aucune fusion demandée
ou réalisée. Les démos et les documents/vecteurs V1 restent présents.

L’inventaire du dépôt et la lecture des rapports V1 ont été complétés par un
examen détaillé du parcours Living Memory, de ses tests, des contrats des deux
moteurs, de l’import Android, du manifeste et des workflows. Graphify a produit
localement 86 nœuds / 89 relations pour les trois fichiers Living Memory V1.
L’analyse et la suite complète Flutter servent de contrôle transversal ; il
ne s’agit pas d’une certification manuelle de tous les exemples C++/web et de
chaque dépendance du dépôt amont.

## Fonctionnalités

- Base privée existante `living-memory-v1.db`, migration SQLite additive vers
  `user_version=2`, transaction pour les nouvelles tables. Refus d’une version
  future avant modification. Profil d’embedding V1 vérifié et inchangé.
- Souvenirs par agent : source, page, passage, citation originale, observation
  ou déduction citée, incertitude, dates UTC, modèle/protocole d’extraction,
  provenance, statut, numéro de version et historique.
- Activation persistante par agent, désactivée par défaut. Extraction à la suite
  des imports TXT/PDF et notes ; reprise manuelle des sources existantes.
- Gemma 4 E2B par ConversationRepository/LiteRT-LM : nouveau contexte sans outil
  pour chaque passage, contrôle de place disponible, sortie JSON stricte,
  rejet des sorties interrompues et des citations absentes.
- EmbeddingGemma 2 via le service V1 : vecteurs de documents ; classement cosinus
  local pour proposer des doublons, sans fusion sémantique automatique.
- Doublon exact du même passage : idempotence. Clé sujet/relation identique avec
  valeurs différentes : contradiction potentielle à revoir. Clés produites
  par le modèle, non garanties ; ni vérificateur universel ni résolution automatique.
- Regroupement explicite : lien entre deux souvenirs, sans effacer les deux
  textes ou leurs sources. Correction : nouveau vecteur, nouvelle version,
  statut à examiner et ancienne citation conservée. Suppression physique du
  souvenir et de ses versions/liens. Supprimer la source purge ses souvenirs.
- Les réponses produites par l’application ne sont jamais envoyées à l’extracteur. Questions et réponses
  ne sont pas soumises à l’extracteur. Aucun statut « fait vérifié » n’est
  accepté dans le JSON ou créé par le moteur.

La recherche RAG ajoute les souvenirs explicitement confirmés par l’utilisateur,
avec attribution observation/déduction/correction et mention de l’absence de
vérification externe. Après une correction, ils redeviennent à examiner avant
réutilisation. Les documents d’origine restent consultables ; une correction
ne réécrit pas la source.

## Limites de ressources

Une seule opération UI à la fois ; inférences séquentielles ; au maximum huit
passages par action, trois candidats par passage, 700 octets UTF-8 par passage,
6000 octets de sortie, 768 tokens de sortie, 1000 souvenirs par agent. Une
reprise SQLite évite de relancer les passages terminés. La liste des souvenirs
est paginée par 20 ; classement sur curseur sans charger toutes les lignes.
Ces plafonds réduisent le travail ; ils ne constituent pas une mesure de RAM,
de batterie, de temps maximal ou de température sur S22. Les modèles V1 restent
chargés selon leur gestionnaire existant, sans promesse de double déchargement.
Un arrêt demande l’arrêt du générateur et bloque les écritures ultérieures ;
il ne garantit pas l’interruption instantanée du parseur PDF natif.

## Contrôles et résultats observés

- 40475389810 : rouge attendu, API V1.1 absente à l’analyse.
- 40475869427 : 29 tests ciblés réussis ; chargement UI échoué car panneau pas
  encore ajouté.
- 40476147447 : 30 tests ciblés réussis ; analyse arrêtée sur dix règles de
  style (blocs `if`), sans erreur de typage ni erreur des tests ciblés.
- Revue indépendante : deux problèmes d’annulation identifiés (correction
  différée et question après ouverture/vérification de contexte différée).
  Régressions dédiées ajoutées avant correction.
- Actions 40477380809 : 35 tests ciblés réussis ; import redondant ensuite retiré.
- Actions 40477834391 : format/analyse OK, suite complète 2965 réussis / 15 ignorés / 1 échec de cohérence de version. Constante kAppVersion alignée sur pubspec sans changer le test.
- Actions 40478470088, code 89de7bd6 : 35 tests ciblés réussis, analyse sans problème, suite complète **2966 réussis / 15 ignorés / 0 échec**. Le build a ensuite été annulé par le workflow concurrent déclenché sur la même branche. Cette exécution ne fournit pas d’APK.
- Revue indépendante de suivi : plus de problème Important signalé par inspection ; les correctifs d’annulation et de dialogue sont couverts par les tests widget.
- Les 15 tests ignorés sont ceux de V1 : 7 spécifiques macOS/iOS, 7 nécessitant TurboJPEG, 1 optionnel de captures de mise en page. Ils ne sont pas comptés comme des succès.
- Actions 40480260704 : source d’application strictement identique à 89de7bd6, APK arm64 compilé. Contrôle arrêté sur le parseur du libellé de certificat (`Signer #1` attendu, `V2 Signer` réel). La signature v2 et la structure étaient valides ; le workflow de vérification a été corrigé.
- Actions **40482049625 : succès** sur les octets de cet artefact : hash conforme au hash de build, signature v2 valide, ABI arm64-v8a seule, EmbeddingGemma présent à la taille attendue. Les formats ancien et actuel du libellé du signataire sont testés par le script de contrôle.

Les tests utilisent SQLite réel sur disque temporaire et des vecteurs
synthétiques explicitement identifiés. Les doubles remplacent les inférences
natives et la conversation, pas le stockage ou l’algorithme de classement.
Le SDK Flutter n’étant pas disponible dans l’espace local, les commandes
Flutter exécutables sont lancées sur les runners GitHub Actions.

## Révision figée et travail concurrent

La source d’application validée est `89de7bd6b76c8ba8889ab1c17b4c1da8b99cf31a`.
Après cette révision, une autre exécution a ajouté des sessions/contexte/recherche
hybride sur la branche demandée. Ces changements ont été préservés. Ce rapport
ne prétend pas valider cette nouvelle HEAD en cours de développement.

Pour éviter l’annulation du build et ne pas écraser ces ajouts, la livraison est
figée sur `work/living-memory-v1.1-apk`. Son workflow compare tous les fichiers
`samples/litert/flutter` avec le commit testé avant de compiler. Les tests
ne sont pas rejoués sur une application strictement identique ; leurs résultats
proviennent de l’exécution 40478470088, et la compilation/les contrôles APK sont
réalisés dans l’exécution isolée indiquée ci-dessous.

[Preuves des tests](https://github.com/tiviniura0/living-memory-android/actions/runs/40478470088/artifacts/12723065512).
La branche principale et la branche V1 n’ont pas été fusionnées ou modifiées
par cette mission. Les 4286 fichiers suivis de la base sont encore présents.

## Téléphone physique : non exécuté

Installation et mise à jour Android, sélecteur SAF réel, migrations sur la base
réelle de Tivini, vrais modèles Gemma/EmbeddingGemma, compréhension du français,
qualité des extractions, négations, résistance réelle aux injections, qualité
de la similarité et des contradictions, latence d’arrêt, mode avion après
redémarrage, RAM maximale, consommation et chauffe. Aucun score de fiabilité
ni pourcentage anti-hallucination n’est déduit des tests synthétiques.

Une citation exacte ne garantit ni sa vérité, ni son contexte complet : une
négation ou attribution tronquée peut rester une sous-chaîne valide. Tous les
candidats restent donc à examiner. Une confirmation utilisateur représente son
avis explicite, jamais une vérification indépendante. Le stockage Android privé
n’est pas chiffré par l’application ; aucun souvenir n’est envoyé à un cloud.
Les fonctions de téléchargement des modèles des démos d’origine sont conservées.

## Installation et sécurité des données V1

L’application garde son identifiant et son fichier SQLite. La migration teste
la préservation des données lors d’une mise à jour compatible. Attention : V1
utilisait une clé Android Debug non pérenne ; si le nouveau certificat diffère,
Android refuse la mise à jour. Ne pas désinstaller V1 pour contourner ce refus :
Android supprimerait ses données privées. L’APK ne permet pas de récupérer la
clé privée d’une ancienne compilation ; l’export/restauration V1 n’existe pas.
**Résultat mesuré : les certificats V1 et V1.1 diffèrent.** La mise à jour directe
de l’ancienne V1 publiée n’est donc pas compatible. La conservation des données
est testée au niveau de la migration SQLite, mais elle ne peut pas être promise
par installation sur une V1 déjà présente avec cette autre signature. Ne pas
désinstaller V1 pour contourner ce blocage. La livraison est adaptée à un essai
sur installation vierge ; une vraie trajectoire de mise à jour nécessite de
résoudre la signature et la migration des données avant intervention sur la V1.
Le test d’installation sur téléphone n’a pas été réalisé.

## Téléchargement et preuves finales

- [Archive APK expérimentale](https://github.com/tiviniura0/living-memory-android/actions/runs/40480260704/artifacts/12723352241), 660 565 913 octets (ZIP).
- APK dans l’archive : `app/outputs/flutter-apk/app-release.apk`.
- Version : **1.1.0+2** ; APK : **897 913 476 octets**, environ 897,9 Mo décimaux.
- SHA-256 APK : `5bb48ab0af06d0649604f0afe03c4d177c051338530c11e062f2ead20f61edb4`.
- SHA-256 certificat V1.1 : `f9959b02ad5ac1f0cd5ff9d9e9f42849d7cc88677e8469b597ba70f9bd8e393f`.
- SHA-256 certificat V1 : `cc90f8b4d170d0410025bab5ba3af71567fd6ecbd420c411230043c7389dc487`.
- EmbeddingGemma embarqué : **484 622 336 octets**. Gemma 4 E2B reste à configurer/importer selon V1.
- [Contrôle indépendant de l’artefact](https://github.com/tiviniura0/living-memory-android/actions/runs/40482049625) et [preuves légères](https://github.com/tiviniura0/living-memory-android/actions/runs/40482049625/artifacts/12722784699).
- [Tests source : 2966 réussis / 15 ignorés](https://github.com/tiviniura0/living-memory-android/actions/runs/40478470088/artifacts/12723065512).
- Source testée : `89de7bd6b76c8ba8889ab1c17b4c1da8b99cf31a`. Commit de packaging : `5cf1cc2e6a6b06da2d7b440143de6a0b75ca39bd` ; les changements suivants concernent les contrôles CI et la documentation, pas l’application.
- [Guide de vérification sur S22](V1_1_PHONE_CHECKLIST.md).

Les artefacts APK sont conservés 14 jours par le workflow ; les preuves légères,
30 jours. Le téléchargement GitHub peut demander une connexion au compte.
L’archive complète dépasse la limite de transfert de fichiers du connecteur de
la session : téléchargement direct sur GitHub, sans ordinateur personnel.

## Tests ajoutés

23 nouveaux cas, plus les 12 tests Living Memory V1, forment les 35 tests ciblés.
La suite complète conserve les tests existants, dont le test de cohérence de version.

| Fichier de test | Cas | Contrôles |
|---|---:|---|
| auto_memory_test.dart | 10 | Migration V1, provenance, profil, agents, déduplication, contradictions possibles, historique, suppression, regroupement, recherche confirmée, JSON strict |
| auto_memory_engine_test.dart | 5 | Intégration SQLite, activation, plafond et reprise, erreur, annulation |
| gemma_memory_extractor_test.dart | 4 | Conversation locale sans outil, citation, interruption, modèle et contexte |
| auto_memory_panel_test.dart | 2 | Interface de revue, fermeture de dialogue, correction annulée et attribution |
| memory_screen_cancellation_test.dart | 2 | Arrêt pendant ouverture et vérification du contexte |


## Sources techniques officielles consultées

- https://developers.google.com/edge/litert-lm/models/gemma-4
- https://developers.google.com/edge/litert-lm/overview
- https://ai.google.dev/gemma/docs/embeddinggemma
- https://developer.android.com/google/play/app-updates

Les poids, chemins, profils et versions des dépendances V1 sont réutilisés ;
aucune nouvelle API IA distante, dépense, ni service de souvenirs cloud ajouté.
