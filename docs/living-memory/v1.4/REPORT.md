# Living Memory V1.4 — livraison et preuves

État : implémentation intégrée ; vérification finale et compilation APK en cours.
Branche exclusive : `work/living-memory-v1.4-extensions`. Aucun merge stable.
Le journal chronologique est [PROGRESS.md](PROGRESS.md), le suivi de revue
[REVIEW.md](REVIEW.md) et la chaîne de compilation [BUILD.md](BUILD.md).

## Provenance

- Source Memory : `32dfa547bf3ff63eec6fa5025c7641db45fc858e`.
- World L1 existant : `5ca4ae5b08c5da6545276b252e39fdbf675430fe`, fusionné avec son historique en `7687f388d7ab774611c8829e32dc1593f432c7f0`.
- CDC World V1.0 retrouvé : `libfile_c2f7c74c670881919ab80056bdbe9a94`, 17 pages ; dossier L0 : `libfile_84f2200fe3908191a8f9fb81b7fc95e8`. Ces références ne sont pas republiées intégralement dans le dépôt public.
- Audits V1.3.1 réutilisés : [AUDIT](../v1.3.1/AUDIT.md), [REVIEW](../v1.3.1/REVIEW.md), [SIGNING](../v1.3.1/SIGNING.md), [STORAGE](../v1.3.1/STORAGE.md). Les nouvelles revues portent sur le diff de mission.
- Spécification et plan approuvés : [design](../../superpowers/specs/2026-10-28-living-memory-v1.4-design.md), [plan](../../superpowers/plans/2026-10-28-living-memory-v1.4.md).

Aucun moteur World recréé. Le code L1 reste inchangé ; seules cinq contraintes de dépendances ont été rendues compatibles avec le verrou applicatif existant. Les huit dépendances path ajoutées au pubspec.lock de l'application ne changent aucune version externe de V1.3.1.

## Réalisation

| Module | Résultat concret | Frontière |
|---|---|---|
| living_memory_core | Stockage canonique extrait, anciens imports compatibles, schéma5 additif, transferts SQLCipher | Aucun import Flutter ou World |
| World L1 existant | Moteur, habitants, carte, déplacements, checkpoints et observateur réutilisés | Règles indépendantes de la mémoire et des modèles |
| living_world_memory | MemoryPort V1, perception, portées monde/agent, reçus persistants, provenance/ticks, publication et révocation | Aucun changement des règles du monde |
| living_memory_extensions | Grants opaques à usage unique, arguments immuables, registre Tools, manifeste strict, Skill approuvé, missions persistantes bornées | Aucun chargement de code tiers ni droit donné au texte généré |
| Hôte Android | Espace World distinct, embedding réel du service existant, contrôles manuels, lecture locale autorisée, transfert SAF | Aucun accès à la base d'une autre application |

L'ingestion suit un checkpoint effectivement sauvegardé ; un échec bloque l'avance et permet un retry idempotent. La recherche applique les ACL avant le classement, puis les revérifie après l'embedding asynchrone. Documents et requêtes utilisent leurs rôles d'embedding respectifs.

Le Skill embarqué et le plugin JSON sont chargés par les composants réels ; le parseur SKILL.md existant est réutilisé. Une approbation du Skill ne constitue pas une autorisation d'outil. Les missions exécutent au plus huit effets par activation, conservent portée/échéance et restent indéterminées après un effet incertain plutôt que le rejouer.

Le client MCP est un sous-ensemble stateless sortant, borné JSON/SSE, de la version2026-07-28 ([spécification officielle](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/docs/specification/2026-07-28/basic/versioning.mdx)). Il refuse un endpoint absent, les redirections et les réponses hors limites. Les tests utilisent un vrai serveur loopback ; aucun serveur externe n'est configuré dans le produit. Pas de conformité MCP complète annoncée.

## Transfert et installations existantes

Export chiffré sous une clé de récupération indépendante ; sélection Android via SAF, copie stream64Kio bornée à1Gio, staging privé confiné et nettoyage sur annulation/erreur. La clé ne traverse pas le canal Android et n'est pas copiée automatiquement dans le presse-papiers. La restauration crée un fichier candidat séparé, vérifie schéma/profil/intégrité, annule les missions et retire les droits persistants du namespace réservé `permission.*`. Les sources et reçus sont conservés ; la base active garde ses droits existants.

Le bouton de transfert porte sur l'espace personnel. La sélection/activation d'un candidat restauré et le transfert atomique d'un ensemble complet monde+checkpoint+mémoire restent des travaux futurs. Une copie restaurée est préparée et vérifiée, sans remplacement automatique d'un fichier actif. Keystore n'est jamais exporté.

ApplicationId conservé. Migration additive4→5 ; un ancien APK n'est pas annoncé capable de rouvrir le schéma5. Ne pas désinstaller ni effacer les données pour contourner une incompatibilité de signature. Aucune clé de production créée. La signature stable nécessite la clé externe d'origine selon la procédure V1.3.1 ; tout APK CI avec opt-in debug reste expérimental. Comparer les certificats avant toute installation.

## Preuves TDD et revue

| Run GitHub Actions | Résultat observé avant le dernier lot |
|---|---|
| [40755565977](https://github.com/tiviniura0/living-memory-android/actions/runs/40755565977) | Rouge initial : packages absents |
| [40757101294](https://github.com/tiviniura0/living-memory-android/actions/runs/40757101294) | Backup13 et extensions14 verts ; transaction imbriquée et effacement mission rouges |
| [40758608307](https://github.com/tiviniura0/living-memory-android/actions/runs/40758608307) | Régressions de revue rouges : schéma, délai et courses |
| [40759820726](https://github.com/tiviniura0/living-memory-android/actions/runs/40759820726) | Backup20, extensions16 verts ; rôle query et widget encore rouges |
| [40811435881](https://github.com/tiviniura0/living-memory-android/actions/runs/40811435881) | World8 verts ; schéma SQL supplémentaire et espaces vides rouges |
| [40812031178](https://github.com/tiviniura0/living-memory-android/actions/runs/40812031178) | Backup22 et extensions17 verts ; SAF absent rouge ; suites L1 et10000ticks verts |
| [40813104637](https://github.com/tiviniura0/living-memory-android/actions/runs/40813104637) | UI2 verts ; SAF7/9 et World8/9 : alias et droits de partage restaurés rouges |
| [40813983620](https://github.com/tiviniura0/living-memory-android/actions/runs/40813983620) | Backup22, extensions17, extraction2, transfert9 et World9 verts ; analyses sans issue ; dernière assertion de défilement UI corrigée ensuite |

Les deux revues indépendantes ont produit des corrections couvertes par régressions. La dernière relecture du delta e06e251f ne confirme plus de défaut important ou critique dans le code ; le résultat CI reste requis. Le point mineur du constructeur World créant séquentiellement ses participants est documenté dans REVIEW.

## Dernière validation et artefacts

En attente du run final. Les nombres de tests, SHAs, liens d'artefacts, ABI, certificat et SHA256 de l'APK seront renseignés uniquement après lecture des journaux et métadonnées produits. Un run en cours ou échoué n'est pas une preuve de livraison APK.

## Limites matérielles et fonctionnelles

Aucun S22 ni émulateur utilisé. Keystore/redémarrage, sélecteur SAF réel, interruption du fournisseur, panne/espace plein, inférence native, RAM/chauffe/batterie et mode avion restent à vérifier selon [INSTALL_S22](INSTALL_S22.md). Les canaux Android simulés et vecteurs déterministes des tests ne sont pas une preuve d'inférence sur appareil.

Gemma4 E2B/E4B, EmbeddingGemma2/profil768, RAG et Auto-Memory sont préservés ; aucune nouvelle inférence native n'est revendiquée. Le monde utilise les règles locales L1 ; ce jalon ne livre pas un village L2 génératif autonome. Les échéances ne tournent qu'au premier plan, sans daemon ni garantie Android continue.

PC/VPS : packages et contrats portables préparés ; aucun serveur, synchronisation, déploiement ou service payant provisionné. Une révocation bloque l'accès futur mais ne retire pas une copie déjà citée. Le sandbox utilisateur Android reste la frontière de sécurité ; les identifiants de portée ne constituent pas une authentification multiutilisateur.
