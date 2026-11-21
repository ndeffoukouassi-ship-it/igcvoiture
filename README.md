# IGC AutoWash — version en ligne

Application web de gestion de lavages automobiles, en français, portée par Impact Global Consulting.

## Architecture

- Site statique Render ; Supabase Auth, Postgres et Storage.
- Un compte propriétaire par centre, données isolées par `auth.uid()` et RLS.
- Tickets, fidélité facultative, bilans et dépenses. Reçus dans un bucket privé.
- Sauvegardes de l’état avec révision pour refuser les écrasements concurrents ; actualisation manuelle entre appareils.
- Les photos sont récupérées avec le jeton du propriétaire ; aucune URL publique de reçu.

## Construire

Node 22 ou plus. `npm ci`, puis `npm test`, puis `npm run build`.
Variables obligatoires : `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` (clé publique uniquement).
Le résultat est dans `build/`. Aucun secret `service_role` n’est requis pour l’application.

## Supabase

Projet dédié : IGC AutoWash (`wofsqsnvpenkpzzyebsn`), région Paris.
Schéma déjà appliqué : `database/schema.sql`. Ne pas le réappliquer sans migration adaptée.
Test d’isolation : `database/security-test.sql` (transaction avec rollback).
Configurer l’URL du site Auth et les URL de redirection pour le domaine Render final, y compris `/?recovery=1`.
La confirmation d’adresse e-mail doit rester activée. Prévoir un fournisseur SMTP de production avant ouverture à de nombreux clients.

## Render

Publier le dépôt sur GitHub puis créer un site statique :
- Build : `cd cloud && npm ci && npm test && npm run build` si le dépôt contient le dossier cloud ; sinon `npm ci && npm test && npm run build`.
- Publication : `cloud/build` ou `build` selon la racine du dépôt.
- Les deux variables ci-dessus doivent être renseignées dans Render.

## Limites de cette première version cloud

- Pas encore de rôles employés, d’administration des abonnements, ni de synchronisation temps réel.
- L’état de chaque centre est un document versionné ; à découper en tables de transactions pour les gros volumes.
- Les suppressions de comptes et le nettoyage des reçus remplacés nécessitent une procédure administrateur.
- Les sauvegardes JSON et CSV restent disponibles. Les données du pilote local ne sont pas transférées automatiquement : conserver un export du navigateur d’origine avant migration.
- Scanner OCR à vérifier sur des plaques réelles. Les paiements restent des enregistrements manuels.

## Espace automobiliste

Depuis un ticket, le propriétaire du centre peut créer un lien de suivi fidélité. Le lien est une capacité de 256 bits ; son empreinte est enregistrée dans une table protégée et le lien lui-même reste dans l’état privé du centre pour permettre de le partager de nouveau.

La route `/#fidelite=...` ne demande pas de connexion et affiche uniquement le nom du centre, la plaque, le compteur et les 50 derniers lavages validés. Le lien est confidentiel ; toute personne qui le possède peut le consulter. Il n’existe pas de recherche publique par plaque.

La fonction de lecture privilégiée est dans un schéma non exposé et contrôle le jeton avant toute lecture. Les politiques n’accordent pas d’accès anonyme aux tables privées. Tests : `database/customer-loyalty-test.sql`.

Le gérant utilise actuellement le compte du centre ; les comptes employés distincts et l’administration IGC restent à développer.

## Comptes gérants et Android

Les propriétaires peuvent inviter des gérants depuis « Mon centre ». L’invitation est à usage unique, valable 7 jours. Les gérants ont des identifiants séparés et peuvent gérer les tickets, les encaissements manuels, les dépenses et les liens de fidélité. Le nom, les tarifs, l’activation de la fidélité et la gestion des accès restent réservés au propriétaire. Les restrictions sont vérifiées par les fonctions SQL côté serveur, pas seulement par l’interface. Le propriétaire peut retirer un accès.

Migrations : `database/managers.sql`. Tests de sécurité avec rollback : `database/managers-test.sql`.

Le projet Android se trouve dans `android/` à la racine du dépôt, avec caméra native et confirmation de la plaque. Il s’agit d’une première version de test connectée ; notifications push et saisie différée hors connexion ne sont pas encore incluses.

## Administration IGC

L’administrateur désigné se connecte avec son compte AutoWash habituel ; son droit est conservé dans une table privée du serveur et n’est pas déduit des métadonnées modifiables du compte. L’écran Administration IGC liste les centres, les contacts propriétaires, le nombre de tickets et gérants, et un suivi manuel des licences (essai, actif, suspendu, échéance, mensualité prévue et notes).

Tarification commerciale IGC AutoWash : 10 000 F CFA de frais d’abonnement à l’inscription du centre, puis 10 000 F CFA par mois. Les tarifs de lavage des véhicules restent configurables par le propriétaire du centre. Ce tarif est affiché dans l'accueil, « Mon centre » et l'administration. Aucun encaissement automatique n’est exécuté ; les mensualités déjà enregistrées ne sont pas modifiées par cet affichage. Une suspension ou une échéance passée bloque les accès du centre et ses gérants, y compris les anciennes voies de lecture/écriture et les reçus. Les changements de licence sont journalisés. L’administrateur conserve l’accès à son propre espace pour éviter de se bloquer lui-même. L’administration ne propose pas de consultation des photos ou des dépenses des autres centres.

Migrations : `database/platform-admin.sql`, puis `database/admin-access-guards.sql`. Tests : `database/platform-admin-test.sql` (transaction avec rollback).
