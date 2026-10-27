# Installation depuis le Samsung S22 Ultra uniquement

1. Télécharger l'artefact APK indiqué dans le rapport de non-régression.
   Dans GitHub sur le téléphone : Actions → Living Memory Android APK →
   exécution réussie → Artifacts. Extraire le ZIP puis ouvrir app-release.apk.
2. Autoriser Android à installer depuis l'application qui ouvre l'APK.
   Il s'agit d'un build d'essai signé avec la clé debug du runner, pas d'un
   APK publié sur Google Play. Aucune clé de signature permanente configurée.
   Une autre compilation peut avoir une signature différente : ne pas désinstaller
   une version contenant des données importantes pour tenter une mise à jour.
3. Ouvrir Living Memory, puis configurer le modèle de chat. Import file…
   utilise désormais le sélecteur Android et une copie en flux. Choisir le
   fichier générique gemma-4-E2B-it.litertlm, puis Use this model / Apply.
   Les fichiers installés dans l'espace privé de Google AI Edge Gallery ne
   sont pas automatiquement accessibles à une autre application.
4. Si tu n'as pas le fichier dans Téléchargements, utiliser le téléchargement
   de modèle proposé par l'application, ou télécharger le fichier officiel :
   https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm
   Un modèle .task ou GGUF n'est pas le bon format. Prévoir plusieurs Go libres.
5. Essayer GPU ; en cas d'échec explicite, choisir CPU. Ne pas sélectionner
   une variante NPU destinée à un autre chipset. Attendre la fin de préparation
   d'EmbeddingGemma et des autres modèles de la démo conservée.
6. À l'accueil, ouvrir Living Memory. « Ma mémoire » est l'agent initial.
   Ajouter une note : « Le code de démonstration est CORAIL-472. »
   Poser « Quel est le code de démonstration ? », d'abord Rechercher puis
   Répondre avec Gemma. Ouvrir le passage [1] pour vérifier la provenance.
7. Créer un agent « aru ». La même question ne doit pas retrouver la note
   personnelle. Ajouter une note différente à Aru et réessayer.
8. Importer un TXT UTF-8 puis un PDF contenant du texte. Vérifier fichier,
   numéro de page et passage. Un PDF scanné sera refusé : pas d'OCR.
9. Fermer et rouvrir l'application pour vérifier la persistance. Activer le
   mode avion après configuration, puis refaire recherche et génération.
   Ce test sur ton téléphone n'a pas été effectué par l'agent de développement.

Les seuils de pertinence sont ajustables et non calibrés pour tes documents.
Une référence valide désigne un passage ; elle ne garantit pas que la réponse
interprète correctement ce passage. Les réponses générées ne sont pas ajoutées
automatiquement à la mémoire. Les notes sont enregistrées explicitement.
