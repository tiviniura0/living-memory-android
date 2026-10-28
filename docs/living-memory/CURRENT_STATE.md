# État Living Memory V1.3 — expérimental

Branche : work/living-memory-v1.3-google-integration. Aucune fusion stable.
Version : 1.3.0+4 ; applicationId et SQLite schéma 4 conservés.
Source applicative vérifiée : cadef86749ea1fe0625f86b0ab1234c12115cff3.
Run réussi : https://github.com/tiviniura0/living-memory-android/actions/runs/40638529913

Assistant chat/rédaction, image sélectionnée, dictée française, WAV PCM16 mono
16 kHz (30 s maximum), lecture et promotion explicite en source sont raccordés
aux services Google existants. Historique borné par agent/projet, frontière du
reset respectée même après compaction. RAG strict, EmbeddingGemma 2 (768),
Auto-Memory et moteur séquentiel E2B/E4B conservés. Registre : suppression privée,
contrôle d’espace et annulation de copie, sans suppression du fichier d’origine.

3038 tests réussis, 15 ignorés ; 129 tests ciblés. Analyse, formatage,
compilation ARM64, manifeste fusionné, dépendances natives, signature et SHA-256
contrôlés. Inference/voix/images natives et Galaxy S22 Ultra : NON TESTÉS.
Les tests IA et audio utilisent des doubles ; aucune mesure de RAM/chauffe ou
preuve de mode avion. Les médias originaux ne sont pas archivés par la mémoire.
La copie SAF initiale du modèle vers le cache n’est pas interrompable par Dart.

Attention : clé debug Actions non pérenne. Ne pas désinstaller une application
contenant des données pour contourner une signature incompatible. Pas d’export
et restauration complète de la base. Suppression de source ≠ suppression des
copies en sessions ; reset actif ≠ suppression des documents/décisions/archives.

Rapport et preuves : [v1.3/REPORT.md](v1.3/REPORT.md),
[v1.3/BUILD.json](v1.3/BUILD.json), [v1.3/AUDIT.md](v1.3/AUDIT.md).
Installation et essais S22 : [v1.3/INSTALL_S22.md](v1.3/INSTALL_S22.md).
Historique V1.2 : [V1_2_VALIDATION.md](V1_2_VALIDATION.md).
