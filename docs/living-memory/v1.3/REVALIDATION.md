# Reprise et vérification V1.3 — 27 octobre 2026 (Tahiti)

## État constaté

Branche reprise : `work/living-memory-v1.3-google-integration`, tête
`c06a46e65f8cd455ece2b8572abab42bf54c01f2`. Le document de correction a été lu.
L'intégration demandée est déjà présente : AssistantSession, MemorySpeech,
MemoryStore et le registre/runtime multimodèle réutilisent les services Google.
Les limites restent celles de REPORT.md ; aucune nouvelle fonction n'est déclarée
opérationnelle sur la seule base de sa présence dans les sources.

Comparaison Git du commit applicatif `cadef86749ea1fe0625f86b0ab1234c12115cff3`
à cette tête : aucun changement sous `samples/litert/flutter` ni dans les
workflows. Seuls sept documents de suivi ont changé. Aucun correctif runtime
supplémentaire n'a donc été introduit pendant cette reprise, et aucun nouveau
build Flutter n'a été lancé : l'APK existant du même code est conservé.

## Preuves revérifiées

- [Run 40638529913](https://github.com/tiviniura0/living-memory-android/actions/runs/40638529913) : API GitHub et journaux du job 122651016772 consultés ; statut success.
- Suite complète : `02:27 +3038 ~15: All tests passed!` ; suite ciblée : `00:15 +129: All tests passed!` ; analyse sans problème. Ce sont les résultats CI existants, pas une nouvelle exécution locale Flutter.
- Compilation : `app-release.apk`, 898044628 octets, uniquement `arm64-v8a`, version 1.3.0+4. Signature v2 valide dans les preuves CI.
- [Archive APK exacte](https://github.com/tiviniura0/living-memory-android/actions/runs/40638529913/artifacts/12795435247), non expirée lors du contrôle. Expiration : 10 novembre 2026 à 19:46, Tahiti.
- [Preuves](https://github.com/tiviniura0/living-memory-android/actions/runs/40638529913/artifacts/12794922655) retéléchargées ; SHA-256 du ZIP comparé au digest API : `1287ecb0ca57720315059f4d704797b2ea247fa5094f53a6c61fdda803353ee9`.
- SHA-256 de l'APK lu dans les preuves : `a6fbffa52ac9b82ee334800695d3439ae6e0f8d2811ef5a62bdf6f2911c7e555`. L'APK complet n'a pas été retéléchargé pendant cette reprise.
- Relancés ici : 4 tests Android source, 5 tests du parseur de signature, 3 tests du contrôleur de dépendances natives ; tous réussis. Les tests du parseur ne vérifient pas à eux seuls une signature APK.
- Relancés sur le manifeste fusionné téléchargé : 4 tests Android réussis. Contrôle du graphe Gradle téléchargé : aucune version refusée, Guava 33.7.2-android et OkHttp 4.9.2 résolus.
- API OSV réinterrogée à 06:56–06:57 UTC le 28 octobre (20:56–20:57 le 27 à Tahiti) : 152 entrées initiales (148 Pub et 4 Maven), puis 147 coordonnées Maven résolues ; aucun avis retourné. Réponses brutes dans RECHECK_DEPENDENCIES.json et RECHECK_NATIVE.json. Couverture partielle des binaires natifs ; aucune certification de sécurité.
- Références distantes contrôlées : main `0f95b7eb0db759ed4a0071756c231c94e36f6c04`, V1.2 `376ccf33353ec101b1c424b6121eb69ecfc55f62`. Aucune branche stable modifiée.

## Validation restant à réaliser

Aucun appareil Android connecté. Génération réelle E2B/E4B, vision, qualité
française STT/TTS, RAM, chauffe, latence, mode avion et permissions réelles :
**non testés sur S22 Ultra**. Les essais Flutter avec doubles ne les prouvent pas.
Suivre [INSTALL_S22.md](INSTALL_S22.md), scénario par scénario, et conserver
commit, empreinte APK, version Android/One UI, SoC et modèle/backend exacts.

Les poids génératifs Gemma doivent être importés séparément ; ne pas confondre
l'EmbeddingGemma embarqué et les modèles génératifs E2B/E4B. Tester chaque modèle
séparément avant la sélection Auto. Les copies sont chargées séquentiellement.

Points ouverts : signature debug Actions non pérenne et différente de V1,
absence d'export/restauration complet, import SAF initial non interrompable,
absence de liste blanche d'hôtes pour les URL HTTPS personnalisées,
stockage non chiffré par l'application, historiques conservés après suppression
d'une source. L'audit n'établit pas la conformité complète aux étapes G et I.

Ne pas désinstaller une ancienne version contenant des données pour contourner
une incompatibilité de certificat. Cet APK reste une version expérimentale ;
aucune fusion stable ni certification de compatibilité S22 n'est effectuée.
