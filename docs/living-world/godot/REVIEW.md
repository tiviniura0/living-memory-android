# Revue indépendante de la tâche 1

Revue en lecture seule demandée avec le skill Superpowers `requesting-code-review`. Premier périmètre : `9946751..414d6ed` ; second passage limité au delta de raccordement `1961e8e`. Aucun audit global du projet n'a été recommencé.

## Constats et traitement

| Constat Important | Traitement |
| --- | --- |
| Le test Kotlin appelait directement les handlers et ne prouvait pas le trajet Flutter complet. | Le script CI lance aussi `flutter test integration_test/godot_host_smoke_test.dart -d emulator-5554`, avec ABI x86_64 propagée. Ce test attend un vrai ready, puis un vrai écho. |
| L'ancien chemin d'upload pouvait publier un APK x86_64 sous un nom ARM64 si la reconstruction ARM64 échouait. | L'APK est copié vers `evidence/godot-delivery/world-godot-task1-smoke-arm64.apk` uniquement après compilation, inspection et vérification de signature réussies ; seul ce chemin est publié. |
| Le premier test de rotation n'attendait pas une configuration/layout effectifs et ne recréait pas l'Activity. | Attente/assertions des dimensions et de l'orientation ; ajout distinct de `ActivityScenario.recreate()`. Une absence de reprise reste un échec. |
| La première recette de recréation utilisait une vue directe non inscrite dans le registre du plugin ; son ancien propriétaire pouvait subsister artificiellement. | Les vues de cette recette et du test de canal sont créées par la vraie factory Flutter, via un helper limité à androidTest. Le vrai plugin ActivityAware assure leur nettoyage. |

Aucun Critical n'a été établi dans le périmètre lu. Aucun Minor n'a été reporté. Les résultats CI restent nécessaires pour confirmer les corrections ; une revue ne prouve pas l'exécution matérielle.

## Limite connue et verdict

Le host refuse la réutilisation de l'instance native après sa destruction. Ce garde-fou évite d'appeler volontairement un état JNI détruit, mais ne remplit pas les vingt réouvertures. La tâche 1 ne peut pas être déclarée complète avec un tel résultat.

Le nom `destroyAndKillProcess` dans la bibliothèque ne suffit pas à prouver un arrêt de Flutter : son corps exact délègue au lifecycle/host. Le chemin privé d'erreur d'initialisation n'a toutefois pas de recette native dédiée ; aucune garantie générale « Flutter ne peut jamais quitter » n'est donnée.

Verdict de revue : livraison expérimentale partielle documentée ; aucune autorisation de merge ni validation opérationnelle complète.

## Hors jugement à ce jalon

Exécution ARM64/S22 ; sécurité JNI complète après détachement/recréation ; fuites/PSS et performance ; gestes de l'hôte Memory, verrou `_needsSync`, générations/restaurations, textures et ACK de frames des tâches suivantes. Ces limites restent visibles dans le rapport de livraison.

## Revue finale ciblée après la CI native

Delta a2b02dee..19d8b693 : aucun nouveau Critical/Important identifié dans l'annulation différée des canaux. Le vrai test intégré passe désormais le démontage. Un Minor de rédaction a été corrigé : le test prévu pour vingt réouvertures s'arrête à la première réouverture refusée ; les suivantes n'ont pas été exécutées. Le rapport conserve les échecs de cycle de vie, l'absence d'exécution ARM64 et la capture invalide. Cette revue ne conclut pas à la tâche 1 complète.
