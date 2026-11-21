# IGC AutoWash Android — APK de test

Application Android hybride : gestion connectée sur `https://igc-autowash.onrender.com`, caméra CameraX et reconnaissance ML Kit intégrées. Le modèle Latin est inclus dans l’APK ; la lecture photo se fait sur le téléphone. Le numéro reconnu doit être confirmé avant d’être recopié dans le ticket.

- Android 8 (API 26) et versions ultérieures.
- Connexion Internet nécessaire pour les comptes, tickets, paiements enregistrés, dépenses et bilans.
- Accès propriétaire et gérant distincts ; invitation depuis Mon centre.
- Pas encore de notifications push ou de saisie différée hors connexion.
- Pas de clé Supabase privilégiée embarquée.
- Le pont natif accepte uniquement les messages du cadre principal et de l’origine AutoWash ; les liens externes s’ouvrent dans le navigateur.
- Sélection photo et galerie pour les reçus ; export vers un emplacement choisi par l’utilisateur et partage Android.

## Construire

JDK 17+, Android SDK 35, Build Tools 35.0.0 et Gradle 8.11.1.

`gradle :app:assembleDebug :app:testDebugUnitTest`

Sortie : `app/build/outputs/apk/debug/app-debug.apk`.

Cet APK est signé avec une clé de débogage, sous l’identifiant `ci.igc.autowash.test`. Il est destiné à des essais, pas à la publication sur Play Store. La signature de production et sa conservation devront être configurées avant commercialisation. Des APK de test compilés sur des machines différentes peuvent nécessiter de désinstaller l’ancienne version, ce qui efface la session locale ; les données sauvegardées dans Supabase ne sont pas effacées.

## Navigation et actualisation (0.2.0-test)

Sur téléphone, les sections de l'application restent accessibles dans une barre de navigation fixe en bas de l'écran : glisser horizontalement pour atteindre les autres rubriques. Le bouton Retour Android ferme d'abord un dialogue ouvert, puis revient à la vue d'ensemble avant de quitter l'application.

L'interface est hébergée sur Render : les changements web apparaissent après son déploiement et un appui sur « Actualiser ». Le numéro de version Android passe de 1 à 2 pour une nouvelle compilation. La clé de signature du nouvel APK doit correspondre à celle de l'application déjà installée pour permettre la mise à jour sans désinstallation.

## Vérification

Tests unitaires du traitement de plaque et compilation. Les essais physiques (autorisation caméra, autofocus, lisibilité, retour au ticket, reçus et export) doivent être réalisés sur les appareils pilotes, notamment le Samsung S22 Ultra.
