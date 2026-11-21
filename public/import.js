function validateBackup(input){
 if(!input||typeof input!=='object'||typeof input.center!=='string'||!input.center.trim()||input.center.length>80)throw Error('Nom du lavage invalide.');
 if(!Array.isArray(input.services)||!input.services.length||input.services.length>30)throw Error('Prestations invalides.');
 if(!Array.isArray(input.tickets)||!Array.isArray(input.expenses||[]))throw Error('Tickets ou dépenses invalides.');
 const safeText=(v,n)=>typeof v==='string'&&v.length<=n;
 const safeId=v=>typeof v==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(v);
 const safeAmount=(n,max=100000000)=>Number.isSafeInteger(n)&&n>=0&&n<=max;
 for(const s of input.services)if(!safeText(s.name,60)||!s.name.trim()||!safeAmount(s.price,1000000)||s.price===0)throw Error('Tarif invalide.');
 const ids=new Set();for(const t of input.tickets){if(!safeId(t.id)||ids.has(t.id)||!safeText(t.plate,25)||!safeText(t.service,60)||!safeText(t.vehicle,40)||!safeText(t.worker||'',50)||!safeText(t.phone||'',30)||!safeAmount(t.amount,1000000)||!['En attente','En cours','Terminé'].includes(t.status)||!['','Espèces','Wave','Orange Money','Offert'].includes(t.payment)||!Number.isFinite(t.created)||(t.paidAt!=null&&!Number.isFinite(t.paidAt)))throw Error('Ticket invalide.');ids.add(t.id)}
 for(const e of input.expenses||[]){if(!safeId(e.id)||ids.has(e.id)||!safeText(e.label,120)||!safeText(e.category,60)||!safeText(e.method,30)||!safeText(e.reference||'',120)||!safeAmount(e.amount)||e.amount===0||!/^\d{4}-\d{2}-\d{2}$/.test(e.date))throw Error('Dépense invalide.');ids.add(e.id);if(e.receiptPhoto&&(!e.receiptPhoto.startsWith('data:image/jpeg;base64,')||e.receiptPhoto.length>600000))throw Error('Photo de reçu invalide.');delete e.receiptPhotoPath}
 const workers=input.workers||[];
 if(!Array.isArray(workers))throw Error('Laveurs invalides.');
 const workerIds=new Set();for(const w of workers){if(!safeId(w.id)||workerIds.has(w.id)||!safeText(w.name,50)||!w.name.trim()||!safeAmount(w.rate,1000000)||typeof w.active!=='boolean')throw Error('Laveur invalide.');workerIds.add(w.id)}
 for(const t of input.tickets){if(t.workerId!=null&&(!workerIds.has(t.workerId)||!safeAmount(t.workerFee,1000000)))throw Error('Attribution laveur invalide.');if(t.workerPaidAt!=null&&(!t.workerId||!Number.isFinite(t.workerPaidAt)||t.status!=='Terminé'))throw Error('Paiement laveur invalide.');}
 return {workers,center:input.center.trim(),loyaltyEnabled:!!input.loyaltyEnabled,services:input.services.map(s=>({name:s.name,price:s.price})),tickets:input.tickets,expenses:input.expenses||[]};
}
function bindImport(){const button=document.getElementById('importBackup');if(!button)return;button.onclick=()=>{if(db.tickets.length||db.expenses.length){notice('L’import est réservé à un espace vide pour conserver les données existantes.');return}document.getElementById('importBackupFile').click()};document.getElementById('importBackupFile').onchange=async event=>{const file=event.target.files[0];if(!file)return;try{if(file.size>15000000)throw Error('Sauvegarde trop volumineuse (15 Mo maximum).');const restored=validateBackup(JSON.parse(await file.text()));if(!confirm(`Importer ${restored.tickets.length} tickets et ${restored.expenses.length} dépenses dans cet espace vide ?`))return;const previous=db;db=restored;if(!await save()){db=previous;return}render();notice('Sauvegarde importée en ligne')}catch(error){alert(error.message||'Sauvegarde illisible.')}finally{event.target.value=''}}}
if(typeof module!=='undefined')module.exports={validateBackup};
