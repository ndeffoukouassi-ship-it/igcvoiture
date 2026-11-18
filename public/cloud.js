/* Cloud-only data access. No fallback to browser-local business data. */
(()=>{
 const config=window.AUTOWASH_CONFIG;
 const gate=document.getElementById('authGate');
 if(!config){gate.textContent='Configuration du service indisponible.';return}
 if(location.hash.startsWith('#fidelite=')){openCustomerLoyalty(config);return}
 const client=createSupabaseClient(config.url,config.key);
 let owner,revision=0,loaded=false,busy=false,formMode='login';
 const photoPaths=new Map();const registeredCustomerTokens=new Set();
 const message=s=>{document.getElementById('authMessage').textContent=s};
 function show(mode='login'){
 formMode=mode;gate.hidden=false;document.getElementById('appShell').hidden=true;
 document.getElementById('authTitle').textContent=mode==='signup'?'Créer le compte de votre lavage':mode==='recovery'?'Choisir un nouveau mot de passe':'Espace propriétaire / gérant';
 document.getElementById('authSubmit').textContent=mode==='signup'?'Créer mon compte':mode==='recovery'?'Enregistrer le mot de passe':'Se connecter';
 document.getElementById('authEmailLabel').hidden=mode==='recovery';document.getElementById('authEmail').required=mode!=='recovery';
 const pass=document.getElementById('authPassword');pass.autocomplete=mode==='login'?'current-password':'new-password';pass.minLength=mode==='login'?1:10;pass.type='password';document.getElementById('togglePassword').textContent='Voir le mot de passe';document.getElementById('togglePassword').setAttribute('aria-pressed','false');
 document.getElementById('authToggle').hidden=mode==='recovery';
 document.getElementById('authToggle').textContent=mode==='signup'?'J’ai déjà un compte':'Créer un compte de lavage';
 }
 async function loadCentre(){
 if(loaded)return;
 const {data:userData,error:ue}=await client.auth.getUser();if(ue||!userData.user)throw Error('Veuillez vous reconnecter.');owner=userData.user.id;
 const invite=new URLSearchParams(location.hash.slice(1)).get('gerant')||sessionStorage.getItem('autowash-manager-invite');
 if(invite){const joined=await client.rpc('autowash_join_manager',{invitation:invite});if(joined.error){sessionStorage.removeItem('autowash-manager-invite');history.replaceState(null,'',location.pathname);throw Error('Invitation gérant invalide, expirée ou déjà utilisée. Actualisez pour retrouver votre espace.');}sessionStorage.removeItem('autowash-manager-invite');history.replaceState(null,'',location.pathname)}
 const {data,error}=await client.rpc('autowash_workspace');if(error)throw error;owner=data.owner_id;window.Cloud.role=data.role;window.Cloud.ownerId=owner;
 revision=data.revision;
 for(const expense of data.state.expenses||[]){if(expense.receiptPhotoPath){const file=await client.storage.from('autowash-receipts').download(expense.receiptPhotoPath);if(file.error)throw Error('Impossible de charger un reçu. Réessayez avant de modifier les données.');expense.receiptPhoto=await blobToDataURL(file.data);photoPaths.set(expense.receiptPhoto,expense.receiptPhotoPath)}}
 window.Cloud.state=data.state;loaded=true;
 document.getElementById('cloudUser').textContent=userData.user.email+' · '+(data.role==='manager'?'Gérant':'Propriétaire');
 const script=document.createElement('script');script.src='app.js?v='+config.appVersion;script.onload=()=>{gate.hidden=true;document.getElementById('appShell').hidden=false};script.onerror=()=>message('Chargement impossible. Actualisez la page.');document.body.append(script);
 }
 function blobToDataURL(blob){return new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result);reader.onerror=()=>reject(Error('Photo illisible'));reader.readAsDataURL(blob)})}
 window.Cloud={state:null,role:'owner',ownerId:null,createManagerInvite:async token=>{if(!owner||Cloud.role!=='owner')throw Error('Réservé au propriétaire');const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token))),b=>b.toString(16).padStart(2,'0')).join('');const {error}=await client.from('autowash_manager_invites').insert({owner_id:owner,token_hash:hash});if(error)throw error;},listManagers:async()=>{const r=await client.rpc('autowash_list_managers');if(r.error)throw r.error;return r.data||[]},revokeManager:async id=>{const r=await client.from('autowash_managers').update({active:false}).eq('owner_id',owner).eq('user_id',id);if(r.error)throw r.error;},customerLinkReady:token=>registeredCustomerTokens.has(token),registerCustomerLink:async(plate,token)=>{if(registeredCustomerTokens.has(token))return;if(!owner||!loaded)throw Error('Connexion requise');const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token))),b=>b.toString(16).padStart(2,'0')).join('');const {error}=await client.from('autowash_loyalty_links').upsert({owner_id:owner,plate,token_hash:hash},{onConflict:'token_hash'});if(error)throw error;registeredCustomerTokens.add(token);},save:async state=>{
 if(!owner||!loaded)throw Error('Connectez-vous avant d’enregistrer.');if(busy)throw Error('Un enregistrement est déjà en cours. Réessayez dans un instant.');
 busy=true;document.getElementById('cloudSaving').hidden=false;document.getElementById('cloudStatus').textContent='Enregistrement…';
 try{
 const next=structuredClone(state);
 for(const e of next.expenses||[]){if(e.receiptPhoto){let path=photoPaths.get(e.receiptPhoto);if(!path){if(!e.receiptPhoto.startsWith('data:image/jpeg;base64,'))throw Error('Le reçu doit être une photo JPEG.');const response=await fetch(e.receiptPhoto);const blob=await response.blob();path=owner+'/'+crypto.randomUUID()+'.jpg';const result=await client.storage.from('autowash-receipts').upload(path,blob,{contentType:'image/jpeg',upsert:false});if(result.error)throw result.error;photoPaths.set(e.receiptPhoto,path)}e.receiptPhotoPath=path;delete e.receiptPhoto}}
 const {data,error}=await client.rpc('autowash_save_workspace',{centre_id:owner,expected_revision:revision,next_state:next});if(error){if(error.code==='42501')throw Error(error.message.includes('OWNER_SETTINGS_ONLY')?'Ces réglages sont réservés au propriétaire.':'Votre accès au centre a été retiré. Reconnectez-vous.');if(error.code==='40001'||error.message.includes('CONCURRENT_EDIT'))throw Error('Un autre appareil a modifié les données. Actualisez la page, puis recommencez cette opération.');throw error}revision=data;document.getElementById('cloudStatus').textContent='Enregistré en ligne';return true;
 }catch(error){document.getElementById('cloudStatus').textContent='Échec de l’enregistrement';throw error}
 finally{busy=false;document.getElementById('cloudSaving').hidden=true}
 }};
 document.getElementById('togglePassword').onclick=()=>{const input=document.getElementById('authPassword'),button=document.getElementById('togglePassword');const visible=input.type==='password';input.type=visible?'text':'password';button.textContent=visible?'Masquer le mot de passe':'Voir le mot de passe';button.setAttribute('aria-pressed',String(visible))};
 document.getElementById('authToggle').onclick=()=>{show(formMode==='signup'?'login':'signup');message('')};
 document.getElementById('authForm').onsubmit=async event=>{
 event.preventDefault();const button=document.getElementById('authSubmit');button.disabled=true;message('Connexion en cours…');
 try{const email=document.getElementById('authEmail').value.trim(),password=document.getElementById('authPassword').value;
 if(formMode==='recovery'){const r=await client.auth.updateUser({password});if(r.error)throw r.error;history.replaceState(null,'',location.pathname);document.getElementById('authPassword').value='';await loadCentre();return}
 const r=formMode==='signup'?await client.auth.signUp({email,password,options:{emailRedirectTo:location.origin}}):await client.auth.signInWithPassword({email,password});if(r.error)throw r.error;document.getElementById('authPassword').value='';
 if(!r.data.session){message('Consultez votre messagerie pour confirmer votre adresse, puis connectez-vous.');return}await loadCentre();
 }catch(error){message(error.message==='Invalid login credentials'?'Adresse ou mot de passe incorrect.':error.message||'Connexion impossible. Réessayez.')}
 finally{button.disabled=false}
 };
 document.getElementById('forgotPassword').onclick=async()=>{const email=document.getElementById('authEmail').value.trim();if(!email){message('Saisissez votre adresse e-mail.');return}const {error}=await client.auth.resetPasswordForEmail(email,{redirectTo:location.origin+'/?recovery=1'});message(error?'Envoi impossible. Réessayez.':'Si cette adresse est enregistrée, un lien de réinitialisation vous sera envoyé.')};
 document.getElementById('cloudLogout').onclick=async()=>{if(busy)return;const {error}=await client.auth.signOut();if(error){alert('Déconnexion impossible. Réessayez.');return}location.reload()};
 document.getElementById('cloudReload').onclick=()=>location.reload();
 client.auth.onAuthStateChange((event)=>{if(event==='SIGNED_OUT'&&loaded){loaded=false;owner=null;location.reload()}if(event==='PASSWORD_RECOVERY'){show('recovery');message('Saisissez un nouveau mot de passe d’au moins 10 caractères.')}});
 (async()=>{show();if(location.hash.startsWith('#gerant=')){const token=new URLSearchParams(location.hash.slice(1)).get('gerant');if(/^[a-f0-9]{64}$/.test(token||''))sessionStorage.setItem('autowash-manager-invite',token)}if(location.hash.startsWith('#gerant='))message('Invitation gérant : connectez-vous ou créez votre compte pour rejoindre le centre.');const {data,error}=await client.auth.getSession();if(error){message('Connexion indisponible. Réessayez.');return}if(data.session){if(new URLSearchParams(location.search).has('recovery')){show('recovery');return}try{await loadCentre()}catch(e){message(e.message)}}})();
})();
