# IGC AutoWash Android — candidat terrain 1.0.0-rc1

Version Android 8 et plus, identifiant stable `ci.igc.autowash`, versionCode 10001. L’APK release est signé séparément avec la clé pérenne d’IGC. Il s’installe à côté des anciennes versions `.test` et `.test2` ; se reconnecter avec le compte du centre pour retrouver les données en ligne.

La caméra intégrée lit les plaques sur le téléphone et demande de confirmer le numéro. Internet reste nécessaire pour les comptes, tickets, données, reçus et bilans. Aucun paiement ni transfert d’argent n’est exécuté automatiquement.

La barre Android affiche la version, Actualiser et Navigateur. Les confirmations, alertes et saisies de l’interface web sont prises en charge pour l’origine AutoWash uniquement. Les changements web arrivent après un déploiement Render et une actualisation ; les changements natifs demandent une nouvelle APK signée avec la même clé et un versionCode supérieur.

## Compilation et signature

JDK 17+, SDK 35, Build Tools 35.0.0 et Gradle 8.11.1.

`gradle :app:assembleRelease :app:testReleaseUnitTest :app:lintRelease --no-daemon`

Sortie : `app/build/outputs/apk/release/app-release-unsigned.apk`. Aligner avec zipalign puis signer avec apksigner ; vérifier le certificat et la signature avant diffusion. La clé et son mot de passe restent hors du dépôt et des artefacts GitHub.

## Validation terrain avant commercialisation

Tester sur les téléphones pilotes : installation, connexion propriétaire/gérant, caméra autorisée/refusée, saisie et confirmation de plaque, choix d’un laveur, ticket et encaissement, lavage terminé et rémunération, annulation de confirmation, dépense avec reçu, export, partage, fidélité, Actualiser, Navigateur et Retour Android. Tester une coupure Internet : aucune sauvegarde ne doit être présentée comme réussie. Vérifier ensuite les données depuis un autre appareil.

La compilation, les tests unitaires et l’analyse Android ne remplacent pas les essais physiques. Ce candidat reste à valider sur le terrain avant commercialisation.
