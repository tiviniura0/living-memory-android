# Protocole matériel — Galaxy S22 Ultra 12 Go

Statut initial : NON EXÉCUTÉ. Ne cocher qu'après observation dans cette application.
Noter variante du S22, version Android, SHA du commit/APK et modèle/backend exact.

1. Vérifier que le run est entièrement vert. Télécharger l'artefact correspondant
   au SHA ; comparer APK-SHA256.txt et apk-metadata.json. Lire le certificat.
   Si l'APK ne peut pas mettre à jour une application contenant des données,
   conserver l'installation : ne pas désinstaller pour forcer le test.
2. Installation vierge ou mise à jour avec certificat compatible. Ouvrir Living
   Memory ; noter agents, documents, souvenirs et sessions existants. Ajouter
   une note témoin à un agent et une autre à un agent distinct, puis redémarrer.
3. Depuis Modèles, importer le .litertlm générique E2B, l'appliquer. Retour dans
   Living Memory : « Enregistrer comme E2B ». Prévoir l'espace pour la copie.
   Tester d'abord Auto et E2B avec ce seul modèle enregistré. Import TXT/PDF,
   recherche et réponse avec citations. Tester refus sans source suffisante.
4. Activer Auto-Memory pour un agent ; extraire un texte court, vérifier citations
   exactes, source/page, statut non vérifié et provenance E2B. Reprendre le lot,
   vérifier l'absence de doublons. Tester contradiction et correction versionnée.
5. Importer/appliquer E4B dans Modèles puis « Enregistrer comme E4B ». Choisir E4B
   dans Living Memory. Même source, même question : vérifier génération réelle,
   provenance E4B, citations et absence de modification des documents/agents.
6. Alterner E2B/E4B dix fois, puis relancer l'application. Relever à chaque essai
   modèle demandé/réussi, temps de chargement/réponse, erreur, RAM et chauffe
   mesurées par un outil disponible. Aucune valeur estimée ne vaut une mesure.
7. Mode Auto : question simple puis comparaison de sources. Observer le choix
   et le dernier modèle réussi. Confirmer qu'un seul générateur est résident,
   avec logs/mesure native si possible (l'UI seule ne mesure pas les allocations).
8. Appuyer sur Arrêter en chargement puis génération. Vérifier absence de
   réponse partielle validée, pas de repli après annulation et mémoire conservée.
9. Tester une erreur E4B récupérable avec fichier invalidé sur installation de
   test sans données importantes ; vérifier erreur visible puis repli E2B.
   Un arrêt complet d'Android n'est pas un repli réussi. Ne pas altérer les
   fichiers privés d'une installation personnelle pour simuler l'erreur.
10. Mode avion, redémarrage, TXT/PDF, recherche, E2B seul puis E4B seul. Vérifier
    qu'aucun téléchargement n'est requis après les imports.
11. Vérifier isolation : aucune source/souvenir/session de l'autre agent ou
    projet dans les résultats. Retour aux autres démonstrations : modèle
    choisi dans Modèles et ses réglages V1.1 conservés.
12. Tests de migration : utiliser une copie contrôlée d'une base V1.1 (schéma 4),
    comparer comptes, identifiants, citations, versions et portée après ouverture
    V1.2. Aucun essai de retour vers un ancien schéma sur les données personnelles.

Fiche à remplir : test | attendu | observé | réussi/échec | preuve/log | durée |
RAM | température | SHA modèle | SHA APK. Tout champ non mesuré reste « inconnu ».
Le critère matériel final est E2B seul ET E4B seul fonctionnels, bascule sans perte,
mode Auto et repli récupérable observés. Il reste non validé tant que ces essais
ne sont pas réalisés sur le téléphone.
