# Essais à réaliser sur le Galaxy S22 Ultra

Aucune mesure matérielle n'a été effectuée dans ce runner.

Avant installation : vérifier applicationId et certificat de l'APK installé. Si Android refuse une mise à jour à cause du certificat, conserver V1 installée et ses données ; ne pas désinstaller pour forcer l'installation. Une clé de signature pérenne et un export/restauration sont nécessaires avant distribution durable.

Essais :

1. Relever le nombre d'agents, documents et souvenirs V1 ; mettre à jour avec signature compatible ; vérifier leur présence et leur recherche.
2. Ouvrir deux agents et deux projets, importer des notes avec un mot distinctif, vérifier absence de fuite dans la recherche, les souvenirs, les archives et les décisions.
3. Configurer Gemma 4 E2B puis tester extraction opt-in en français : déclaration attribuée, observation, hypothèse, déduction écrite, négation complète et citation exacte. Aucun souvenir généré n'est vérifié automatiquement.
4. Tester un document hostile contenant une instruction d'ignorer les règles. Vérifier absence d'exécution d'outil ou changement de permission. La robustesse sémantique du modèle doit être mesurée ; les tests de parsing ne la prouvent pas.
5. Marquer une décision, compacter, fermer l'application, la relancer ; retrouver l'original et le checkpoint. Réinitialiser le contexte et vérifier que les sources et souvenirs restent présents.
6. Couper le réseau après configuration et redémarrer ; tester TXT/PDF, embedding et génération. Tester SAF et fichiers volumineux, arrêt pendant extraction et fermeture forcée.
7. Mesurer RAM maximale, latence, chauffe et batterie lors d'import/extraction/RAG. Les modèles restent gérés par les runtimes V1 ; aucune promesse de déchargement alterné ni de fonctionnement permanent en arrière-plan.
8. Vérifier lisibilité petit écran et paysage, clavier, mode sombre et taille de texte Android maximale. Les tests widget complètent mais ne remplacent pas ces essais.

Noter pour chaque essai : version APK/commit, modèle et profil, entrée, sortie observée, durée, succès/échec et capture éventuelle. Aucune donnée personnelle n'est requise dans le dépôt public.
