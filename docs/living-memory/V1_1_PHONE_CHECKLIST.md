# Essai V1.1 sur le Galaxy S22 Ultra

Ces manipulations n’ont pas encore été réalisées sur un téléphone physique.
Elles ne remplacent pas les résultats Actions, et Actions ne les remplace pas.

## Avant installation

- Lire V1_1_REPORT.md pour la comparaison de certificat avec V1.
- Si Android refuse la mise à jour, ne pas désinstaller V1 pour forcer
  l’installation : cela effacerait ses données privées. Garder V1 et ses données.
- Extraire `app-release.apk` depuis l’artefact GitHub indiqué dans le rapport.
- Conserver les fichiers TXT/PDF originaux en dehors de l’application.

Si V1 est déjà installée avec des données, arrêter ici : son remplacement sur
ce même profil doit attendre une solution de migration sûre. La suite suppose
une installation vierge, et ne constitue pas une invitation à supprimer V1.

## Premier essai, sans données sensibles

1. Configurer Gemma 4 E2B avec le parcours V1 et laisser EmbeddingGemma terminer
   sa préparation. Un modèle dans AI Edge Gallery n’est pas automatiquement
   partagé avec le stockage privé de cette application.
2. À l’accueil, ouvrir Living Memory. Vérifier l’agent sélectionné. La
   mémorisation automatique doit être désactivée au premier usage de cet agent.
3. L’activer. Ajouter la note de test fictive :
   « Pour cet essai, le code du casier est CORAIL-472. »
   L’import doit rester présent même si Gemma refuse ou échoue à produire le JSON.
4. Consulter les souvenirs. Chaque candidat doit afficher sa source, sa page,
   son passage, sa date, son agent et sa citation originale. Il reste à examiner.
   Le modèle peut ne rien extraire : noter le comportement sans inventer un résultat.
5. Confirmer explicitement un candidat. Poser une question et vérifier
   l’attribution et les références. Une confirmation personnelle n’est pas
   une vérification indépendante du fait.
6. Corriger le texte. Vérifier que l’ancienne version apparaît dans l’historique
   et que la correction redevient à examiner. La confirmer avant sa réutilisation
   comme souvenir dans le RAG. Le document original n’est pas réécrit.
7. Réimporter la même note : vérifier l’absence de doublon exact. Pour les
   documents longs, utiliser « Extraire / reprendre » pour continuer après huit
   passages. Les passages déjà terminés ne doivent pas relancer Gemma.
8. Ajouter deux notes contradictoires de test. Consulter les liens proposés,
   sans supposer que tous les conflits seront détectés. Le regroupement doit
   conserver les deux citations et ne confirmer aucun fait automatiquement.
9. Créer un autre agent. Les souvenirs et le réglage de mémorisation du premier
   ne doivent pas apparaître dans celui-ci.
10. Désactiver la mémorisation, puis ajouter une note : sa source V1 doit être
    indexée, sans nouvelle extraction automatique.
11. Tester « Arrêter » pendant une extraction, une réponse et une correction.
    Vérifier qu’aucune nouvelle écriture ne se produit après l’arrêt ; le moteur
    natif peut demander un délai avant de rendre la main.
12. Supprimer un souvenir : vérifier la disparition de ses versions/liens.
    Sa source reste accessible. Supprimer une source de test : ses souvenirs
    doivent disparaître aussi. Ne pas utiliser de vraie donnée pour cet essai.
13. Fermer, rouvrir, puis tester en mode avion après configuration des modèles.
    Vérifier recherche, extraction, correction, génération et persistance.

## Mesures à relever

Noter modèle/backend utilisés, durée pour un passage, durée pour huit passages,
délai d’arrêt, RAM maximale observée, température et batterie avant/après une
session comparable. Arrêter le test si le téléphone devient inconfortablement
chaud. Sans mesure sur cet appareil, aucune autonomie, température ou vitesse
n’est garantie. Le test des modèles est distinct des tests synthétiques CI.
