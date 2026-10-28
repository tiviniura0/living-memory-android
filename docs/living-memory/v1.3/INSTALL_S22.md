# Installation et validation Galaxy S22 Ultra — V1.3 expérimentale

## Préserver l’installation existante

1. Télécharger l’artefact du run réussi correspondant au commit exact indiqué
   dans le rapport. Extraire `app-release.apk`, `APK-SHA256.txt`,
   `apk-signature.txt` et `apk-metadata.json`. Le ZIP de preuves seul n’est pas
   un APK. Un run échoué peut aussi publier un artefact portant « android ».
2. Vérifier l’empreinte avec `sha256sum app-release.apk` ou
   `Get-FileHash app-release.apk -Algorithm SHA256` sur Windows ; comparer à
   l’empreinte du rapport du même run. L’APK embarque les modèles publics et
   requiert aussi de l’espace pour leur extraction et les modèles personnels.
3. Comparer le certificat de l’APK installé à celui du nouvel APK. Les builds
   Actions utilisent actuellement une clé debug non pérenne : une mise à jour
   peut être refusée. **Ne pas désinstaller l’ancienne application contenant
   des données pour contourner une signature différente.** Aucun export et
   restauration de toute la base ne sont actuellement disponibles.
4. Pour une mise à jour compatible : `adb install -r app-release.apk` (Android
   Platform Tools installé et débogage USB autorisé). Pour une installation
   vierge : ouvrir l’APK dans Mes fichiers et autoriser cette source d’installation
   ponctuellement, ou `adb install app-release.apk`.
5. Confirmer version 1.3.0+4, nom Living Memory et ABI arm64-v8a dans les preuves.
   La variante matérielle exacte du S22 (SoC/Android) doit être notée avant tests.

## Préparer les modèles

Ouvrir Modèles ; importer un `.litertlm` compatible ou télécharger depuis une
URL HTTPS choisie. Fournir une empreinte SHA-256 issue de l’éditeur lorsqu’elle
existe. Ne pas assimiler empreinte calculée et origine authentifiée. Les GGUF,
`.task` et safetensors ne deviennent pas compatibles par changement d’extension.

Appliquer le modèle puis, dans Living Memory, enregistrer le slot E2B ou E4B.
Une copie privée complète est nécessaire ; une réserve de 64 Mio est contrôlée
à cette étape sur Android. Ce contrôle ne garantit pas l’espace restant pour
les autres services. Tester E2B d’abord, puis E4B séparément. Un encodeur image
présent et activé est nécessaire à l’analyse d’image. Ne pas activer de backend
NPU sans bundle et matériel compatibles.

## Scénarios à consigner, sans données personnelles

| Essai | Action et critère observé | Résultat à remplir |
|---|---|---|
| Texte | « Discuter », puis « Rédiger » : réponse complète affichée, marquée non vérifiée | non exécuté |
| Mémoire | Ajouter « Le code du dossier fictif est LAGON42 » ; rechercher/répondre avec Gemma, afficher citations | non exécuté |
| Isolation | Nouvel agent/projet : LAGON42 absent de ses sources et résultats ; retour au premier agent : source présente | non exécuté |
| Persistance | Fermer/relancer : sources, agents, choix des modèles et sessions préservés | non exécuté |
| PDF/TXT | Importer fichiers synthétiques ; PDF texte lisible, scan sans OCR signalé, refus fichier excessif | non exécuté |
| Image | Choisir une photo fictive, analyser ; annulation du sélecteur ne crée rien ; modèle sans vision : erreur explicite | non exécuté |
| Provenance | Conserver description : source marquée IA et hash PNG ; l’image originale n’est pas archivée | non exécuté |
| Dictée | Refuser puis accorder micro ; dicter en français, terminer ; relire texte avant recherche/enregistrement | non exécuté |
| WAV | Importer un WAV PCM16 mono 16 kHz de moins de 30 s ; fichier mal formé, compressé ou trop long refusé ; relire la transcription | non exécuté |
| TTS | Lire réponse puis arrêter ; vérifier sortie, volume, absence de lecture en arrière-plan ; qualité française à noter | non exécuté |
| Annulation | Arrêter pendant ouverture, génération, dictée ; aucune sortie partielle enregistrée comme source | non exécuté |
| Hors ligne | Une fois modèles installés, activer mode avion : texte, RAG, image, dictée et lecture ; noter chaque parcours séparément | non exécuté |
| Modèles | Import, hash attendu faux, annulation, manque d’espace, suppression du slot ; fichier d’origine conservé | non exécuté |
| Suppression | Source et souvenirs dérivés supprimés ; anciennes réponses de sessions restent, conformément au message UI | non exécuté |
| Pression mémoire | E2B puis E4B/Auto ; relever échec, RAM, latence et température ; ne pas confondre absence de crash et validation prolongée | non exécuté |

Noter pour chaque essai : date, commit/APK hash, certificat, Android/One UI,
SoC, modèle exact/hash/backend, espace libre initial, durée et résultat observé.
N’inscrire aucune mesure estimée comme résultat réel. Conserver les logs sans
texte personnel. Ne pas fusionner vers une branche stable avant cette validation.
