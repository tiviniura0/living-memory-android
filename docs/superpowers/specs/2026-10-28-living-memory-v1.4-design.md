# Living Memory V1.4 + Living World AI — spécification proposée

Statut : **à valider ; aucune implémentation V1.4 annoncée**.
Mission : Tivini, 28 octobre 2026 (Pacific/Tahiti).
Branche exclusive : `work/living-memory-v1.4-extensions`.
Base : `32dfa547bf3ff63eec6fa5025c7641db45fc858e` de
`work/living-memory-v1.3.1-security`.

## 1. Résultat attendu et limites de connaissance

Étendre l'application existante avec une frontière de mémoire utilisable par
Living World AI, des Tools contrôlés, des Skills déclaratifs, un client MCP et
des missions persistantes. Conserver les données et les moteurs existants.
Prouver l'isolation de deux agents, le partage explicite et la reprise après
fermeture avec SQLite/SQLCipher réels. Livrer un APK ARM64 expérimental vérifié,
sans qualifier l'inférence matérielle de fonctionnelle sur la seule base de doubles.

Le dépôt fourni contient une architecture Living World future, mais aucun monde
externe identifié. Les recherches GitHub accessibles `user:tiviniura0 living` et
`user:tiviniura0 world` n'ont trouvé aucun dépôt distinct. Ce résultat ne prouve
pas qu'un tel projet n'existe pas. Hypothèse proposée : fournir un adaptateur
local et une démonstration intégrée dans ce dépôt. Si un Living World AI existe
ailleurs, son dépôt/commit et son contrat doivent être lus avant de revendiquer
une intégration effective à ce projet. Une fixture à deux agents ne remplace pas
cette intégration externe.

## 2. Base réutilisée, sans nouvel audit global

- Rapports faisant référence : `docs/living-memory/v1.3.1/{REPORT,AUDIT,REVIEW,STORAGE,SIGNING}.md`.
- Code applicatif de la dernière compilation réussie : `f73a8e13c72173362630648513ffe81020b0e727`.
- Run historique confirmé via GitHub : https://github.com/tiviniura0/living-memory-android/actions/runs/40654444799.
- Les 3 060 tests réussis et 15 ignorés sont les résultats consignés pour V1.3.1,
  pas une exécution fraîche V1.4. Douze tests Python ont été réexécutés au cadrage.
- `CURRENT_STATE.md`, `LIVING_WORLD_ARCHITECTURE.md` et certains passages du
  master plan sont antérieurs au chiffrement V1.3.1 ; leurs mentions « futur »
  ne doivent pas écraser les preuves plus récentes.
- Réutiliser `MemoryStore`, `ReliabilityEngine`, `ContextLifecycleManager`,
  `AssistantSession`, `AutoMemoryEngine`, `MultiModelEngine`, `MemoryKey` et les
  transports de modèles durcis.
- Réutiliser `SkillStoreService`, `SkillRepository`, `SkillCatalog` et le parseur
  SKILL.md existants. Ne pas créer un second parseur ou un second moteur natif.

## 3. Approches et choix proposé

| Approche | Avantage | Coût et limite |
|---|---|---|
| A. Modules Dart dans l'application, adaptateurs vers les services existants | Tests SQLCipher et parcours Android directs ; changements progressifs | Les interfaces doivent rester indépendantes de l'UI |
| B. Extraire dès maintenant plusieurs packages multiplateformes | Distribution PC facilitée | Réorganisation large, risques de régression et duplication de configuration |
| C. Ajouter un serveur/VPS et un protocole réseau propriétaire | Plusieurs clients dès le départ | Authentification, exploitation et coûts hors besoin immédiat |

**Recommandation : A.** Préparer des contrats sérialisables et versionnés pour
PC/VPS ; reporter extraction des packages, serveur, synchronisation et monde
avancé. Cette décision est proposée pour revue, pas présumée approuvée.

## 4. Contrats et limites des modules

Racine applicative conservée : `samples/litert/flutter/lib/living_memory/`.
Conserver les ports existants de `module_contracts.dart` et introduire des
enveloppes V1 explicites dans un sous-dossier `extensions/`. Une version majeure
inconnue est refusée avant effets. Aucun renommage global des API historiques.

| Module proposé | Responsabilité et contrat |
|---|---|
| `extensions/contracts.dart` | Enveloppes V1, identifiants stables, limites, sérialisation stricte et erreurs sans données privées |
| `extensions/security_manager.dart` | Approbation hors modèle ; autorisation liée au scope, outil, arguments figés, échéance, identifiant et révision du plugin |
| `extensions/tool_registry.dart` | Adaptateurs approuvés, validation des entrées/sorties, provenance, délais et annulation |
| `extensions/plugin_manifest.dart` | Manifeste déclaratif versionné ; IDs, capacités et empreintes ; aucun code téléchargé |
| `extensions/skills_manager.dart` | Adaptateur du catalogue existant ; instruction chargée seulement après approbation de son empreinte |
| `extensions/mcp_client.dart` | Client sortant uniquement ; version explicitement supportée, liste d'outils autorisés et résultats distants non fiables |
| `world/world_memory.dart` | Observations et souvenirs privés, publications explicites, provenance et tick de simulation |
| `world/world_runtime.dart` | Pilotage local borné à deux agents, partage contrôlé, appels mémoire réels et inférence séquentielle |
| `extensions/agent_runtime.dart` | Mission persistante, étapes bornées, états et validation des actions par la politique |
| `extensions/scheduler.dart` | File persistante, échéance, annulation et reprise explicite au premier plan |
| `extensions/extensions_panel.dart` | Gestion utilisateur des approbations, démonstration du monde et états réels des missions |
| `backup/memory_backup.dart` | Export chiffré indépendant du Keystore ; restauration vérifiée dans un espace séparé |

Les champs `userId/agentId/projectId/worldId` identifient une portée ; ils ne
constituent pas une authentification. Refuser un `userId` autre que `local` dans
les adaptateurs Android V1.4. Le code de confiance choisit la portée ; le modèle,
le SKILL.md et un serveur MCP ne peuvent ni la changer ni attribuer une permission.

## 5. Persistance et Living World

Migration additive schéma 4 → 5, transactionnelle. Ne pas modifier les vecteurs,
le profil EmbeddingGemma 2 à 768 dimensions ni les tables de sources historiques.
Une base de version supérieure doit être refusée avant modification. V1.3.1 ne
doit pas être présentée comme capable de rouvrir une base migrée V1.4.

Ajouter des tables préfixées pour mondes, participants, événements, publications,
permissions, missions et étapes. FK et index par portée ; suppression d'agent
étendue aux nouveaux objets sans toucher aux autres agents. Les publications
restent étiquetées comme observations simulées, affirmations ou dérivés cités,
jamais comme faits vérifiés du monde réel. Les événements sont identifiés par
`worldId/eventId`, avec auteur, tick entier non négatif et parents.

Une observation privée est indexée par l'API mémoire existante dans la portée
de l'agent et du monde. Un événement rejoué avec même ID et mêmes données est
idempotent ; même ID avec contenu différent est refusé. La validation de
membership précède lecture et écriture. Indexation et enregistrement ne doivent
pas laisser d'événement partiel en cas d'échec d'embedding.

Le partage exige une publication explicite et une permission distincte. Un
destinataire ne peut lire que les publications de son monde autorisé ; aucune
recherche sur tous les corpus privés. Une référence vers une source privée
n'ouvre pas son accès. Révocation/suppression retire l'accès futur à la
publication et à son index partagé ; elle ne prétend pas effacer une copie déjà
citée dans un historique indépendant. La consultation des réponses conserve le
contrôle de citations de `ReliabilityEngine` et l'abstention.

## 6. Tools, Skills, plugins et MCP

Premiers outils limités à lire la mémoire de sa portée, proposer un souvenir
et lire/publier une observation du monde autorisé. Une proposition d'IA reste
candidate ; aucune promotion silencieuse. Pas de shell, installation de code,
fichier arbitraire, action financière ou accès Android global ajouté.

Une permission est émise par le gestionnaire après geste utilisateur ou règle
locale explicitement approuvée. Un `PermissionGrant` public construit à la main
ne suffit jamais : il doit correspondre à un enregistrement valide. Refuser
rejeu, expiration, modification d'arguments/scope/plugin, révocation et outil
inconnu. Les grants sont consommés atomiquement avant effet ; une erreur après
effet produit un état indéterminé, pas une répétition automatique dangereuse.

Un manifeste/Skill modifié perd son approbation. Les instructions SKILL.md sont
des données déclaratives ; elles n'accordent aucune capacité supplémentaire.
L'approbation se fait sur un instantané immuable pour éviter une modification
entre contrôle et exécution. Borne proposée : 4 Kio pour SKILL.md, comme le
service existant ; 64 Kio par manifeste et 1 Mio par résultat MCP.

MCP : implémenter et tester un sous-ensemble documenté de la révision
`2026-07-28` sur Streamable HTTP, requêtes JSON-RPC avec métadonnées et en-têtes
cohérents, réponses JSON et SSE bornées. Ne pas mélanger sa négociation sans
sessions avec le handshake de 2025-11-25. Aucune rétrocompatibilité implicite.
Capacités V1.4 : catalogue d'outils et appel explicitement autorisé ; pas de
sampling, elicitation ou exécution automatique des demandes serveur. Refuser
explicitement les capacités non prises en charge.

Serveur configuré et approuvé par l'utilisateur ; HTTPS, pas de credentials dans
l'URL, pas de redirection automatique, pas de découverte de serveurs imposée par
un document. Secrets dans Keystore, jamais dans les manifestes/export/logs.
L'absence de configuration ne doit déclencher aucun réseau. Fixture HTTP de
loopback autorisée uniquement via injection du transport de test. Tests réels
de transport local distincts de l'accès à un serveur distant non fourni.

Référence primaire vérifiée au cadrage :
https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http.
La conformité complète MCP n'est pas un critère revendiqué par ce sous-ensemble.

## 7. Missions et automatisations

États persistants : queued, running, awaitingPermission, succeeded, failed,
cancelled, indeterminate. Identité liée à la portée complète. Maximum proposé :
8 étapes par activation, un appel natif génératif à la fois, délais bornés ;
une annulation interdit tout nouvel effet et marque les appels déjà partis.
Une mission retrouvée running après arrêt devient indeterminate jusqu'à revue ;
aucun effet externe n'est rejoué sans preuve d'idempotence.

La V1.4 traite les échéances au premier plan et lors d'une reprise explicite.
Pas de promesse de daemon Android, d'heure exacte, de WorkManager permanent ou
de Foreground Service sans étude et tests dédiés. Les fondations d'autonomie
sont opérationnelles si des missions réelles traversent stockage, politique et
outils ; une simple liste d'interfaces ne suffit pas.

## 8. Export, restauration et signature

Réutiliser SQLCipher pour produire un export chiffré avec une clé de récupération
aléatoire indépendante de la clé Android Keystore ; jamais exporter le Keystore.
La clé de récupération est montrée à l'utilisateur hors logs et ne figure ni
dans l'archive ni dans GitHub. Aucun mot de passe humain utilisé directement
comme clé. Inclure profil/version/métadonnées à l'intérieur du conteneur chiffré.

Restaurer d'abord dans un nouveau fichier/espace privé : clé correcte, intégrité
SQLCipher/SQLite/FK, version supportée, profil et données obligatoires contrôlés.
Ne pas remplacer la base active au seul import. La sélection du nouvel espace
nécessite une confirmation utilisateur et la fermeture des connexions ; conserver
l'espace antérieur jusqu'à vérification. Permissions, secrets MCP et missions
ne sont jamais réactivés automatiquement après restauration.

SAF pour sélectionner la destination/source ; pas de permission de stockage large.
Les poids de modèles ne sont pas copiés dans l'export mémoire. Tester export,
réouverture indépendante, clé erronée, fichier tronqué, refus d'écraser la base,
profil incompatible, schéma futur, manque d'espace simulé et interruption avant
activation. La résistance à une panne matérielle reste un essai sur appareil.

ApplicationId conservé. Réutiliser le refus de release sans signature externe.
Ne créer aucune clé de production dans cette session. Comparer le certificat
installé à celui du candidat ; aucun conseil de désinstallation pour contourner
l'incompatibilité. APK expérimental clairement nommé si clé stable indisponible.

## 9. Preuves d'acceptation par phase

| Phase | Preuves exigées avant de la qualifier de validée |
|---|---|
| 1. Reprise | SHA source, provenance audit/run, inventaire réutilisé, contrôles locaux consignés |
| 2. Architecture | Revue de cette spécification, puis plan `writing-plans` versionné et revu |
| 3. Mémoire/monde | TDD et tests SQLite réels de deux agents, partage et reopen ; parcours UI branché |
| 4. Extensions | Tests refus/rejeu/révocation, Skills existants, manifestes hostiles, client MCP local JSON/SSE |
| 5. Missions | Persistance, bornes, annulation, reprise après crash et statut indéterminé |
| 6. Conservation | Migrations anciennes, FTS, RAG, Auto-Memory, E2B/E4B, profil et SQLCipher/Keystore préservés |
| 7. Transfert/signature | Export/restauration réelle ; aucune activation de grant restauré ; comparaison de certificat |
| 8. Livraison | Revue indépendante, corrections, analyse, suite complète et APK ARM64 inspecté au même commit |

Tests d'intégration pivots : A et B dans W, C hors W ; secret A absent chez B ;
publication A accessible à B après accord ; C refusé ; isolation entre projets
et mondes ; doublon d'événement ; source supprimée ; révocation ; échec
d'embedding ; tentative d'injection via texte/Skill/MCP ; fermeture/réouverture
chiffrée conservant ces propriétés ; effacement d'agent sans rémanence accessible
dans les nouvelles tables. Les entrées malformées doivent être refusées avant I/O.

Le rapport final doit séparer : tests réels SQLCipher, modèles simulés, transport
local, serveur distant, APK compilé et essais S22. Aucune mesure RAM/chauffe,
batterie, mode avion, vision/voix ni inférence native n'est extrapolée des tests
hôtes. Ne pas dépenser pour hébergement, API, runner payant ou matériel.

## 10. Validation demandée

Valider l'approche A et le périmètre ci-dessus, notamment le monde local intégré,
le scheduler au premier plan et l'export vers un espace séparé. Si le but est de
brancher un Living World AI existant, identifier son dépôt avant de figer le
plan d'intégration. Exécution proposée : implémentation native dans cette session,
commits par phase et revue indépendante selon `requesting-code-review`.

Après revue de cette spécification : produire le plan détaillé avec
`writing-plans`, le faire revoir, puis appliquer TDD et les validations de phase.
Ces validations de conception viennent du skill brainstorming installé ; aucun
code produit ne doit être écrit en prétendant qu'elles ont déjà eu lieu.
