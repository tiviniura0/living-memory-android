# Chaîne de validation V1.4

La branche work/living-memory-v1.4-extensions est le seul emplacement de cette
mission. Les SHAs publiés dans PROGRESS et REPORT font foi ; aucune branche
stable n'est fusionnée ou déplacée.

SDK Flutter3.47.3 et actions CI épinglées, Java17, Ubuntu24.04. Le SDK local
n'étant pas disponible, les tests Dart/Flutter sont exécutés par GitHub Actions.
Aucun téléchargement alternatif non vérifié ou simulateur natif n'est présenté
comme preuve matérielle.

- living-memory-v14.yml : contrats ciblés, format/analyse, suites Dart L1,
  observateur Flutter, headless10000ticks et frontières portables.
- build-apk.yml : dépendances verrouillées, modèles publics avec empreintes,
  contrats sécurité V1.3.1, mémoire et suite Flutter complète, format/analyse,
  release ARM64, audit des dépendances natives, manifeste fusionné, signature,
  présence SQLCipher, ABI unique et empreinte EmbeddingGemma2.

L'opt-in LM_ALLOW_EXPERIMENTAL_DEBUG_SIGNING=true est explicite dans la CI.
Aucune clé de signature stable n'est créée. Les instructions et exigences de
signature stable restent celles de V1.3.1/SIGNING.md.

Les artefacts de preuve légers contiennent les journaux, diff de formatage,
SHA256, certificat et métadonnées APK. Un run en cours ou échoué n'est pas une
livraison APK validée. REPORT sera renseigné seulement après lecture du résultat
final et des contrôles exécutés.
