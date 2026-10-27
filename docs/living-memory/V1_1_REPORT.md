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
- Aucun chemin de mémorisation d’une réponse générée. Questions et réponses
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
- Validation finale et APK : résultats à compléter après exécution Actions.

Les tests utilisent SQLite réel sur disque temporaire et des vecteurs
synthétiques explicitement identifiés. Les doubles remplacent les inférences
natives et la conversation, pas le stockage ou l’algorithme de classement.
Le SDK Flutter n’étant pas disponible dans l’espace local, les commandes
Flutter exécutables sont lancées sur les runners GitHub Actions.

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
La compatibilité de signature doit être mesurée sur l’APK final puis indiquée
ici, sans promettre une mise à jour conservant les données avant cette preuve.

## Sources techniques officielles consultées

- https://developers.google.com/edge/litert-lm/models/gemma-4
- https://developers.google.com/edge/litert-lm/overview
- https://ai.google.dev/gemma/docs/embeddinggemma

Les poids, chemins, profils et versions des dépendances V1 sont réutilisés ;
aucune nouvelle API IA distante, dépense, ni service de souvenirs cloud ajouté.
