# Frontière de mémoire pour Living World AI

## Implémenté dans cette V1
- `agents(id, name)` : id stable explicite, indépendant du nom d'un modèle.
- `documents(id, agent_id, name, digest, kind, created_at)` : provenance et date
  d'import, dédoublonnage SHA-256 à l'intérieur d'un agent.
- `chunks(document_id, page, ordinal, content, vector)` : passages citables.
- `profile(name, dimension)` : identité d'espace d'embedding verrouillée.
- `MemoryStore.search(agentId, vector)` : filtre SQL obligatoire avant classement.
- `MemoryStore.deleteDocument(agentId, id)` : suppression limitée au propriétaire.
- Chaque question ouvre une conversation neuve, sans outils : pas d'historique
  conversationnel conservé d'un agent à l'autre.

La table de profil est commune à la base, les corpus sont séparés par agent.
Cette isolation est logique, au sein du même utilisateur Android ; elle n'est
pas une séparation cryptographique entre utilisateurs ou processus compromis.

Une note est un document de `kind=note`. Une réponse générée n'est jamais
réinsérée automatiquement comme un fait. La création et l'import des notes
se font actuellement depuis l'écran, pas depuis un monde autonome.

## Contrat pour une extension ultérieure (non implémentée)
Un futur orchestrateur local pourra fournir à l'indexeur : agentId, événement,
source et temps du monde. Pour ne pas casser les installations V1, prévoir une
migration SQLite versionnée ajoutant world_id, world_tick, event_kind,
importance et parent/provenance, plutôt que modifier les anciens passages.
L'événement conserve son texte original ; une réflexion/synthèse doit citer
ses événements parents et rester étiquetée comme dérivée.

L'orchestrateur devra utiliser le même modèle/profil pour requêtes et
passages, attendre une indexation transactionnelle, limiter les tâches natives
simultanées et ne pas lancer un second moteur de génération par agent.
En cas de changement de modèle, reconstruire un index distinct sans effacer
l'ancien avant validation. La V1 refuse un profil incompatible sans l'effacer.

La recherche exhaustive cosinus suffit à un corpus borné à 10 000 passages
par agent ; aucun benchmark de latence sur S22 n'a été réalisé. Elle est
synchrone côté Dart dans cette V1. Pour de plus gros corpus, une évolution
devra déplacer ce travail hors de l'isolate UI ou utiliser un index vectoriel
avec filtrage par agent, en conservant les tests d'isolation et de provenance.

Pas encore présents : simulation du monde, scheduler en arrière-plan, API IPC,
mémoires partagées contrôlées, permissions par agent, chiffrement applicatif,
export/restauration, consolidation automatique et évaluation sémantique réelle.
