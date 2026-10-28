# Living Memory — correction de stratégie Google AI Edge (27 octobre 2026)

## Décision
Conserver le dépôt existant et la base Flutter dérivée de `google-ai-edge/litert-samples/samples/litert/flutter`. **Ne pas réécrire l'application ni repartir du dépôt Google.** Living Memory reste le moteur indépendant de mémoire durable pour des assistants et pour Living World AI.

Branche de référence : `work/living-memory-v1.2-multimodel`, commit `376ccf33353ec101b1c424b6121eb69ecfc55f62`. Les modifications futures se font sur une branche dédiée, sans toucher aux branches stables. Cet engagement est une orientation d'architecture et non une certification de compatibilité.

## Constat vérifié dans le code source
- `samples/litert/flutter/README.md` décrit déjà chat vocal, photo jointe, RAG local, mémoire visuelle en RAM et agent skills.
- `samples/litert/flutter/pubspec.yaml` contient `flutter_edge_ai`, `flutter_edge_ai_litertlm`, `flutter_edge_ai_rag`, `flutter_edge_ai_speech`, `flutter_edge_ai_sqlite`, `image_picker`, `record`.
- Le pipeline GitHub Actions V1.2 (run 40579317895) a réussi l'analyse, les tests logiciels, la compilation ARM64 et un contrôle de signature/contenu d'APK.
- Ces éléments **ne prouvent pas** que chaque chemin multimodal, chaque import ni chaque permission fonctionnent sur un Galaxy S22 Ultra. Une partie du code provient des exemples Google : présence du code ≠ validation du produit.

## Architecture cible
1. **Couche expérience utilisateur** : chat, rédaction, analyse de documents, images et audio, choix des modèles, permissions explicites.
2. **Adaptateurs d'inférence** : LiteRT-LM pour modèles `.litertlm`, LiteRT pour modèles `.tflite`, gestion de téléchargement contrôlé et vérifié, chargement séquentiel E2B/E4B.
3. **Living Memory autonome** : SQLite, provenance, agent_id, dates, versions, déduplication, contradictions, rétention, export et suppression; le moteur doit rester accessible sans UI.
4. **RAG multimodal** : importer TXT/PDF puis images/audio; stocker source et texte ou vecteurs dérivés, citer la source et isoler les mémoires de chaque agent.
5. **Living World AI** : consommer l'interface mémoire et les capacités d'inférence via adaptateurs, sans dépendance directe à l'interface Flutter.

## Ordre d'implémentation, avec critères d'acceptation
- [ ] **A. Cartographie réelle** : relever dans l'arborescence les implémentations et tests du chat, de l'image, de l'audio, des imports et de Living Memory; indiquer pour chaque fonction «présent dans le code / testé en CI / testé sur appareil».
- [ ] **B. Baseline sans régression** : exécuter tests existants, vérifier l'APK et conserver l'artefact avant modification; ne pas utiliser de données personnelles dans les essais.
- [ ] **C. Contrats d'intégration** : définir interfaces et tests pour `ChatProvider`, `ImageAnalysisProvider`, `SpeechToTextProvider`, `TextToSpeechProvider`, `MemoryRepository` et `ModelManager`. Brancher le code déjà disponible avant d'ajouter un autre moteur.
- [ ] **D. Texte** : prompt → réponse affichée; rédaction/résumé; recherche mémoire avec citations; conversations isolées par agent; tests de refus d'affirmations sans source.
- [ ] **E. Image** : permission de sélection seulement à l'action de l'utilisateur; image → réponse; provenance de l'image conservée; absence de partage externe par défaut.
- [ ] **F. Son** : permission micro à la demande; fichier/enregistrement → transcription; texte → lecture audio; fichiers effaçables; mode hors ligne effectivement testé.
- [ ] **G. Modèles** : import et téléchargement consentis, origines autorisées, empreinte SHA-256 lorsqu'une valeur de confiance existe, annulation, stockage libre contrôlé, incompatibilité clairement signalée, mesure RAM/température/latence sur S22 Ultra.
- [ ] **H. Sécurité** : auditer `AndroidManifest.xml`, composants exportés, logs, trafic réseau, stockage, permissions, dépendances et licences des modèles. Automatiser les contrôles vérifiables.
- [ ] **I. Validation sur vrai appareil** : scénario texte, PDF, photo, transcription, TTS, RAG, redémarrage/rappel, suppression de données, hors-ligne, coexistence E2B/E4B, mémoire sous pression; noter résultats réels.

## Garde-fous
- Aucune modification des branches V1/V1.1/V1.2 ni destruction de base SQLite.
- Pas de déclaration «100 % local», «sécurisé» ou «compatible S22 Ultra» sans essais probants.
- Aucune reprise automatique d'exemples/licences tierces sans vérification (certains modèles, exemples et dépendances ont des licences distinctes).
- Conserver l'architecture modulaire pour la migration future PC/VPS; mesurer avant d'optimiser.
- Éviter les duplications : privilégier les composants Flutter Google déjà présents, et documenter chaque remplacement.

## Références
- https://github.com/google-ai-edge/litert-samples/tree/main/samples/litert/flutter
- https://github.com/google-ai-edge/gallery
- https://github.com/tiviniura0/living-memory-android/actions/runs/40579317895

## Statut de cette correction
**Décision et plan enregistrés uniquement**. Cette étape ne modifie pas encore le runtime ni l'APK. Les étapes A à I sont à implémenter et à valider.
