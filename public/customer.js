function normalizeLoyaltyPlate(plate){return String(plate).toUpperCase().replace(/[^A-Z0-9]/g,'')}
function customerLoyaltyUrl(plate){const token=db.loyaltyLinks?.[normalizeLoyaltyPlate(plate)];return token?location.origin+'/#fidelite='+token:''}
function newLoyaltyToken(){return Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('')}
async function prepareCustomerLink(plate){
 const key=normalizeLoyaltyPlate(plate);let token=db.loyaltyLinks?.[key];
 if(!token){const previous=db.loyaltyLinks;db.loyaltyLinks={...(previous||{}),[key]:newLoyaltyToken()};if(!await save()){db.loyaltyLinks=previous;throw Error('Le lien n’a pas pu être enregistré.')}token=db.loyaltyLinks[key]}
 await Cloud.registerCustomerLink(key,token);return customerLoyaltyUrl(plate);
}
async function customerLinkDialog(plate){
 try{
 const url=await prepareCustomerLink(plate);let dialog=document.getElementById('customerLinkDialog');if(!dialog){dialog=document.createElement('dialog');dialog.id='customerLinkDialog';document.body.append(dialog)}
 dialog.innerHTML=`<div class="dialog-head"><h2>Fidélité de l’automobiliste</h2><button type="button" class="icon" id="closeCustomerLink">✕</button></div><p>Plaque : <strong>${esc(plate)}</strong></p><p class="hint">Ce lien donne accès aux dates des lavages et au compteur cadeau de ce véhicule, dans votre centre. Partagez-le uniquement avec son propriétaire.</p><label>Lien personnel<input id="customerLinkValue" readonly></label><div class="filters"><button id="copyCustomerLink" type="button">Copier le lien</button><button id="shareCustomerLink" type="button">Partager au client</button></div><p id="customerLinkMessage" role="status"></p>`;
 document.getElementById('customerLinkValue').value=url;document.getElementById('closeCustomerLink').onclick=()=>dialog.close();
 document.getElementById('copyCustomerLink').onclick=async()=>{try{await navigator.clipboard.writeText(url);document.getElementById('customerLinkMessage').textContent='Lien copié.'}catch{document.getElementById('customerLinkValue').select();document.getElementById('customerLinkMessage').textContent='Copiez le lien sélectionné.'}};
 document.getElementById('shareCustomerLink').onclick=async()=>{try{if(navigator.share)await navigator.share({title:'Ma fidélité — '+db.center,text:'Retrouvez vos dates de lavage et votre compteur cadeau pour '+plate,url});else{await navigator.clipboard.writeText(url);document.getElementById('customerLinkMessage').textContent='Lien copié : collez-le dans le message au client.'}}catch(error){if(error.name!=='AbortError')document.getElementById('customerLinkMessage').textContent='Utilisez le bouton Copier le lien.'}};
 dialog.showModal();
 }catch(error){alert(error.message||'Création du lien impossible. Réessayez.')}
}
async function openCustomerLoyalty(config){
 const gate=document.getElementById('authGate');const shell=document.getElementById('appShell');shell.hidden=true;gate.hidden=false;
 const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const token=new URLSearchParams(location.hash.slice(1)).get('fidelite');
 const client=createSupabaseClient(config.url,config.key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false,storageKey:'autowash-customer'}});
 gate.innerHTML='<div class="auth-card customer-card"><h1>Ma fidélité automobile</h1><p role="status">Chargement de votre compteur…</p></div>';
 async function refresh(){
 try{if(!/^[a-f0-9]{64}$/.test(token||''))throw Error('Lien invalide. Demandez votre lien personnel au centre de lavage.');
 const {data:s,error}=await client.rpc('autowash_customer_loyalty',{access_token:token});if(error)throw Error('Service momentanément indisponible. Réessayez.');if(!s)throw Error('Ce lien est introuvable ou a été désactivé. Contactez votre centre de lavage.');
 const progress=Math.min(s.paidCount,9);const title=!s.enabled?'Fidélité désactivée par le centre':s.eligible?'Votre lavage cadeau est disponible 🎁':s.giftPending?'Votre lavage cadeau est en cours':`Encore ${s.remaining} lavage${s.remaining>1?'s':''} avant le cadeau`;
 const percent=Math.round(progress/9*100);
 gate.innerHTML=`<div class="auth-card customer-card"><span class="eyebrow">ESPACE AUTOMOBILISTE · IGC AUTOWASH</span><h1>${escape(s.center)}</h1><p class="customer-plate">${escape(s.plate)}</p><div class="customer-reward"><h2>${escape(title)}</h2><div class="customer-progress" role="progressbar" aria-label="Lavages payés avant le cadeau" aria-valuemin="0" aria-valuemax="9" aria-valuenow="${progress}"><div style="width:${percent}%"></div></div><p><strong>${progress} / 9 lavages terminés et payés</strong></p><p class="hint">Après 9 lavages validés, le prochain peut être offert si le centre a activé la fidélité. Le compteur repart après l’attribution du cadeau.</p></div><div class="panel-head"><h2>Mes dates de lavage</h2><button id="refreshCustomer" type="button">Actualiser</button></div><p>${s.totalVisits} lavage${s.totalVisits>1?'s':''} validé${s.totalVisits>1?'s':''} au total.</p>${s.visits.length?`<table class="customer-history"><thead><tr><th>DATE</th><th>TYPE</th></tr></thead><tbody>${s.visits.map(v=>`<tr><td>${escape(new Date(v.date).toLocaleDateString('fr-FR',{timeZone:'Africa/Abidjan',day:'2-digit',month:'long',year:'numeric'}))}</td><td>${v.gift?'🎁 Offert':'Lavage validé'}</td></tr>`).join('')}</tbody></table>`:'<p class="hint">Aucun lavage terminé et validé pour le moment.</p>'}<p class="hint">Les 50 derniers passages sont affichés. Votre centre met à jour ce suivi après validation des lavages.</p><p class="hint">Gardez ce lien personnel : toute personne qui le possède peut consulter ce suivi.</p></div>`;
 document.getElementById('refreshCustomer').onclick=async event=>{event.target.disabled=true;await refresh()};
 }catch(error){gate.innerHTML=`<div class="auth-card customer-card"><h1>Ma fidélité automobile</h1><p role="alert">${escape(error.message)}</p><button id="retryCustomer" type="button">Réessayer</button></div>`;document.getElementById('retryCustomer').onclick=refresh}
 }
 await refresh();
}
