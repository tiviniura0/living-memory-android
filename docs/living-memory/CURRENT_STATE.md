# État Living Memory V1.4 — expérimental

Branche exclusive : `work/living-memory-v1.4-extensions`. Aucune fusion stable.
Version : `1.4.0+6` ; applicationId conservé ; migration additive SQLCipher4→5.
Source Memory : `32dfa547bf3ff63eec6fa5025c7641db45fc858e`.
World L1 réutilisé : `5ca4ae5b08c5da6545276b252e39fdbf675430fe` ; historique
fusionné en `7687f388d7ab774611c8829e32dc1593f432c7f0`, moteur non recréé.

## Reprise courte

Lire ce fichier, [rapport V1.4](v1.4/REPORT.md) et
[journal V1.4](v1.4/PROGRESS.md), puis inspecter le diff depuis le dernier SHA
validé. Le [plan approuvé](../superpowers/plans/2026-10-28-living-memory-v1.4.md)
garde les critères. Réutiliser les audits V1.3.1 ; ne pas relancer un audit global
ni relire tous les rapports historiques sans changement qui le justifie.

## Modules

- `packages/living_memory_core` : implémentation mémoire canonique ; anciens
  imports Flutter compatibles, sans dépendance Flutter ou simulation.
- World L1 : contrats, moteur, agent_runtime, persistence, observateur et CLI
  existants conservés. `living_world_memory` adapte son MemoryPort : perception,
  mémoire privée, partage explicite, provenance et reçus persistants.
- `living_memory_extensions` : Tools autorisés, grants à usage unique,
  manifestes JSON, Skill via parseur existant, client MCP borné et file de
  missions persistante au premier plan. Aucun serveur MCP configuré dans l'UI.
- Hôte Android : espace monde distinct, moteur L1 local et embedding existant ;
  export personnel SAF chiffré et vérification d'un candidat restauré distinct.
  Les droits persistants et missions ne sont pas réactivés dans la copie.

Gemma4 E2B/E4B, EmbeddingGemma2/768, RAG, Auto-Memory, multimodalité et
Keystore sont conservés. La mémoire reçoit et expose les événements du monde ;
les décisions des habitants restent pilotées par les règles L1.

## Validation et limites

Source applicative validée : `a569a2cb434d5d58ac26bc049294353c20655ca1`.
[APK et preuves](https://github.com/tiviniura0/living-memory-android/actions/runs/40859640335/artifacts/12892006101).
CI réussie :3121tests Flutter,15ignorés ;208tests mémoire/LLM ;69contrats ciblés
et73tests L1 ; headless10000ticks. Format, analyses, dépendances natives,
manifeste fusionné, signature et ABI contrôlés. Détails dans REPORT/BUILD.json.
Aucune réussite matérielle supposée. Tests IA/embeddings et canaux Android
utilisent des doubles ; la persistance SQLCipher et le moteur L1 sont réels.

Aucun S22/émulateur, aucune mesure RAM/chauffe/batterie ou inférence native.
Pas de village L2 génératif, daemon Android, serveur PC/VPS, synchronisation,
activation automatique d'un fichier restauré ou transfert global monde+mémoire.

Signature CI debug expérimentale, non pérenne. Comparer les certificats avant
mise à jour ; ne pas désinstaller ni effacer les données pour contourner un
refus. Signature stable : [procédure V1.3.1](v1.3.1/SIGNING.md).
Essais matériels à réaliser : [protocole V1.4](v1.4/INSTALL_S22.md).

Historique : [V1.3.1](v1.3.1/REPORT.md), [V1.3](v1.3/REPORT.md),
[V1.2](V1_2_VALIDATION.md). Les résultats historiques ne sont pas attribués à V1.4.
