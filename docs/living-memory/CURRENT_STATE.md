# État Living Memory — version d'essai compilée

Source initiale préservée : 659a03c49af38e45d235c1c7fdeb504b82fbb4ea.
Version APK : 2ebcad7ae79805019ed242555c0170d90484b8b2.

Confirmé : analyse Flutter sans problème ; 2943 tests réussis / 15 ignorés ;
APK arm64 897782148 octets compilé dans Actions 40434835372.
Contrôle indépendant 40437013088 : hash conforme, signature Android v2 valide
(certificat Android Debug), ABI arm64-v8a, EmbeddingGemma intégré, Bouncy Castle
1.86 réellement résolu. Voir NON_REGRESSION.md pour les liens et empreintes.

La dernière mise à jour documentaire et le workflow de contrôle ne changent
pas le code de l'application compilée. La branche de travail est conservée.

Implémenté : SQLite privé distinct de kb.db, agents séparés, import TXT/PDF texte,
notes, recherche cosinus et passages citables, conversations neuves sans outils,
import Android des modèles en flux. Gemma 4 est à importer/configurer ;
EmbeddingGemma 2 740M est inclus dans l'APK.

Non testé : installation et sélecteur réel S22, vraies inférences, qualité
sémantique, mode avion, RAM/latence/chauffe. Pas d'OCR, chiffrement applicatif,
export/restauration ou monde autonome. La signature debug n'est pas pérenne.

Prochaine étape : essai téléphone décrit dans INSTALL_S22.md. Ne pas
assimiler une compilation et des tests synthétiques à une validation sur S22.
