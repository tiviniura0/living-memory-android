# Living Memory V1.4 — rapport en cours de validation

Statut : développement intégré, validation finale et APK non encore acquis.
Branche exclusive : work/living-memory-v1.4-extensions. Aucun merge stable.

## Provenance et réutilisation
Base Memory32dfa547 ; historique World L1 5ca4ae5 fusionné au commit7687f388.
CDC V1.0 et dossier L0 retrouvés ; leur absence de dépôt séparé ne signifie pas
absence de projet. Références et plan détaillés dans PROGRESS.md et le plan
Superpowers du28octobre. Audits V1.3.1 réutilisés, pas de nouvel audit global.

## Réalisation à vérifier au commit livré
- Une implémentation mémoire canonique en package, anciens imports compatibles.
- Adaptateur MemoryPort L1 : perception, portée monde/agent, sources avec tick,
  reçus persistants idempotents, partage explicite et révocation.
- Hôte Android réutilisant moteur, carte, déplacements et sauvegardes L1 ;
  espace monde distinct de la mémoire personnelle, même gestion Keystore.
- Tools locaux soumis à un grant à usage unique ; manifeste déclaratif et
  SKILL.md via le parseur existant ; file de missions persistante au premier plan.
- Client MCP sortant borné JSON/SSE, sous-ensemble2026-07-28, sans serveur
  configuré ou connexion implicite ; tests de transport local, pas de preuve
  d'un serveur externe.
- Export SQLCipher et restauration vers fichier séparé avec clé de récupération,
  validation de schéma/profil/intégrité et missions restaurées désactivées.

## Modules et frontières

| Module | Responsabilité | Dépendance exclue |
|---|---|---|
| living_memory_core | Stockage canonique, migrations, transfert SQLCipher | Flutter et simulation |
| World L1 existant | État, règles, déplacements, checkpoints et observateur | Mémoire privée et modèles |
| living_world_memory | Adaptateur MemoryPort, perception, partage et provenance | Règles de simulation |
| living_memory_extensions | Grants, manifests, client MCP, missions bornées | Code tiers exécutable |
| Hôte Android | Keystore, embedding réel existant et gestes utilisateur | Accès interapplications |

Contrats versionnésV1 ; schémas inconnus refusés. Le client MCP vise le
sous-ensemble stateless2026-07-28 documenté dans la spécification officielle :
https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/docs/specification/2026-07-28/basic/versioning.mdx
Aucune conformité intégrale ou interopérabilité externe n'est annoncée.

## Installations existantes et signature
ApplicationId conservé. Migration additive4→5 ; les anciennes versions ne sont
pas annoncées capables de rouvrir une base5. Ne pas désinstaller ni effacer les
données pour contourner une signature incompatible. Aucune clé de production
créée ; procédure stable V1.3.1/SIGNING.md réutilisée. Tout APK CI avec opt-in
debug reste expérimental, certificat à comparer à l'installation existante.

## Limites à conserver dans le rapport définitif
Aucun appareil S22/émulateur ; Keystore/reboot/panne/espace plein, inférence native,
RAM/chauffe/batterie et mode avion non testés. Monde en règles locales, pas un
village L2 génératif complet. Gemma E2B/E4B, RAG, Auto-Memory et profil768 conservés,
mais leur présence ne prouve pas une nouvelle inférence réelle.

Les échéances ne s'exécutent qu'au premier plan, sans daemon ni garantie Android
continue. PC/VPS : contrats et packages portables préparés ; aucun serveur,
synchronisation ou déploiement. Une révocation retire l'accès futur, pas une
copie déjà citée. Les limites logiques du sandbox utilisateur Android demeurent.

L'export/restauration conserve la base active et n'exporte pas Keystore.
Le parcours SAF dédié est raccordé ; ses tests CI restent en cours. L'activation
d'un espace restauré reste non livrée dans ce jalon ; préserver l'application
installée et la clé de récupération. Le transfert atomique d'un ensemble complet
monde+mémoire entre appareils reste un lot futur, pas un export mémoire seul.

Les résultats, SHAs, runs, ABI, certificat et SHA256 de l'APK seront renseignés
uniquement après observation des commandes et du run final.
