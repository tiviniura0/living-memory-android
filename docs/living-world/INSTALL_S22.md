# Installation sur S22 Ultra
APK expérimental ARM64, application distincte com.tivini.livingworld. Ne pas désinstaller Living Memory.
1. Ouvrir le run GitHub Actions lié au commit de livraison et télécharger l'artefact `world-l1-apk-<SHA>` depuis un compte autorisé.
2. Extraire le ZIP, ouvrir `app-release.apk`, autoriser temporairement l'installation depuis l'application ayant ouvert le fichier puis installer **Living World**.
3. Aucun modèle à télécharger. Démarrer le village, déplacer et pincer la carte, sélectionner un habitant, observer collecte/consommation/repos dans le journal.
4. Sauvegarder, revenir à l'accueil Android puis rouvrir. Le temps ne doit pas avancer en arrière-plan ; la reprise demande une action explicite.
5. Tester les quatre coins, les boutons de zoom, le glissement sans sélection, le plafond abaissé, le mode avion, puis 30 min à 5 habitants selon BENCHMARK.md.
L'APK est signé avec une clé de test de CI éphémère tant qu'une clé durable n'a pas été choisie. Une mise à jour en place peut être refusée si le certificat change. Exporter le JSON avant tout remplacement de cette seule application. Ne pas désinstaller Living Memory pour résoudre un conflit.
Retour arrière : conserver l'export JSON et l'ancien APK. Les versions de sauvegarde futures sont refusées ; aucune migration silencieuse. Revenir à une sauvegarde compatible sur copie.
