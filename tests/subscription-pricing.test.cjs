const test=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');

const source=path=>readFileSync(path,'utf8');

test('Les deux tarifs commerciaux AutoWash restent visibles',()=>{
 const accueil=source('public/index.html');
 const gestion=source('public/app.js');
 const admin=source('public/admin.js');
 for(const [label,text] of [['accueil',accueil],['Mon centre',gestion],['administration',admin]]){
  assert.match(text,/10 000 F CFA/,label+' : tarif de 10 000 F CFA');
  assert.match(text,/mensualit|Mensualit|par mois/,label+' : indication mensuelle');
 }
 assert.match(accueil,/frais d’abonnement/i);
 assert.match(gestion,/Frais d’abonnement/);
 assert.match(admin,/Frais d’abonnement/);
});

test('Aucun encaissement automatique déclaré',()=>{
 const gestion=source('public/app.js');
 const admin=source('public/admin.js');
 assert.match(gestion,/sans prélèvement automatique/);
 assert.match(admin,/Aucun paiement n’est prélevé automatiquement/);
});


test('Administration : total tarif standard séparé des montants saisis',()=>{
 const admin=source('public/admin.js');
 assert.match(admin,/Tarif mensuel standard/);
 assert.match(admin,/Mensualités actuellement enregistrées/);
 assert.match(admin,/Non renseigné/);
 assert.match(admin,/À vérifier/);
 assert.match(admin,/Ce total est une projection au tarif standard, pas une somme encaissée/);
});
