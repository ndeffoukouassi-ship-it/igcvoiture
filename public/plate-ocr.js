/* Extract plausible plate text without changing ambiguous O/0 or I/1. */
function plateCandidates(text){
 const clean=String(text).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase();
 const found=[];
 for(const raw of clean.split(/[\n\r]+/)){
  const line=raw.replace(/COTE\s*D[ '\u2019]*IVOIRE|IMMATRICULATION|REPUBLIQUE|LICENSE|PLATE|COTE|IVOIRE/g,' ').replace(/[^A-Z0-9 -]/g,' ').trim();
  const parts=[line,...line.split(/\s{2,}/)];
  for(const part of parts){
   const compact=part.replace(/[^A-Z0-9]/g,'');
   if(compact.length<4||compact.length>12||!/[A-Z]/.test(compact)||!/[0-9]/.test(compact))continue;
   const letters=(compact.match(/[A-Z]/g)||[]).length,digits=(compact.match(/[0-9]/g)||[]).length;
   if(letters>6||digits<2||digits>8)continue;
   const transitions=(compact.match(/[A-Z](?=\d)|\d(?=[A-Z])/g)||[]).length;
   const score=digits*3+Math.min(letters,4)*2+(transitions<=3?8:0)-(compact.length>10?10:0);
   found.push({plate:compact,score});
  }
 }
 return [...new Map(found.sort((a,b)=>b.score-a.score).map(c=>[c.plate,c])).values()].sort((a,b)=>b.score-a.score);
}
const PlateScanner=(()=>{
 let worker,initializing,run=0,previewUrl;
 const status=s=>document.getElementById('ocr').textContent=s;
 function cancel(){run++;if(previewUrl){URL.revokeObjectURL(previewUrl);previewUrl=null}document.getElementById('ticketForm').querySelector('[type="submit"]').disabled=false;document.getElementById('photo').disabled=false;}
 async function library(){if(window.Tesseract)return;await new Promise((resolve,reject)=>{const s=document.createElement('script');s.src='ocr/tesseract.min.js?v=5.1.1';s.onload=resolve;s.onerror=()=>reject(Error('Le lecteur ne se charge pas. Vérifiez votre connexion Internet.'));document.head.append(s)})}
 async function getWorker(job){
 if(worker)return worker;
 if(!initializing)initializing=(async()=>{await library();return await Tesseract.createWorker('eng',1,{workerPath:location.origin+'/ocr/worker.min.js',corePath:location.origin+'/ocr/core',langPath:location.origin+'/ocr/lang',workerBlobURL:false,logger:m=>{if(job===run){const p=Math.round((m.progress||0)*100);status(m.status==='recognizing text'?`Lecture de la plaque… ${p} %`:'Préparation du lecteur… Premier chargement : connexion Internet nécessaire.')}}},{load_system_dawg:'0',load_freq_dawg:'0',load_number_dawg:'0'})})();
 try{worker=await initializing;return worker}catch(error){initializing=null;throw error}
 }
 function imageCanvas(bitmap,crop,contrast){
 const sx=crop?bitmap.width*.04:0,sy=crop?bitmap.height*.20:0,sw=crop?bitmap.width*.92:bitmap.width,sh=crop?bitmap.height*.60:bitmap.height;
 const scale=Math.min(2,1800/sw,2200/sh);const canvas=document.createElement('canvas');canvas.width=Math.round(sw*scale);canvas.height=Math.round(sh*scale);
 const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.fillStyle='#fff';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(bitmap,sx,sy,sw,sh,0,0,canvas.width,canvas.height);
 if(contrast){const pixels=ctx.getImageData(0,0,canvas.width,canvas.height);for(let i=0;i<pixels.data.length;i+=4){const y=pixels.data[i]*.299+pixels.data[i+1]*.587+pixels.data[i+2]*.114;const c=Math.max(0,Math.min(255,(y-128)*1.5+128));pixels.data[i]=pixels.data[i+1]=pixels.data[i+2]=c}ctx.putImageData(pixels,0,0)}
 return canvas;
 }
 async function scan(file){
 if(!file)return;if(file.size>20*1024*1024){status('Photo trop volumineuse : 20 Mo maximum.');return}
 cancel();const job=run;const field=document.getElementById('plate');const previousValue=field.value;
 const submit=document.getElementById('ticketForm').querySelector('[type="submit"]');submit.disabled=true;document.getElementById('photo').disabled=true;
 previewUrl=URL.createObjectURL(file);document.getElementById('preview').src=previewUrl;document.getElementById('preview').hidden=false;status('Photo reçue. Lecture automatique en cours…');
 let bitmap,timer;
 try{
 const outcome=await Promise.race([(async()=>{
 try{bitmap=await createImageBitmap(file)}catch{throw Error('Photo illisible. Prenez une photo JPEG ou choisissez une autre image.')}
 const w=await getWorker(job);if(job!==run)return null;
 await w.setParameters({tessedit_char_whitelist:'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -',tessedit_pageseg_mode:'11',preserve_interword_spaces:'1'});
 const all=[];
 for(const [crop,contrast,psm] of [[false,false,'11'],[true,true,'6'],[false,true,'6']]){
  if(job!==run)return null;await w.setParameters({tessedit_pageseg_mode:psm});const image=imageCanvas(bitmap,crop,contrast);const result=await w.recognize(image);
  const candidates=plateCandidates(result.data.text);all.push(...candidates.map(c=>({...c,confidence:result.data.confidence})));
  if(candidates.length&&result.data.confidence>=65)break;
 }
 return all.sort((a,b)=>(b.score+b.confidence*.15)-(a.score+a.confidence*.15))[0]||null;
 })(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Lecture trop longue. Réessayez avec une photo cadrée de près sur la plaque.')),60000)})]);
 if(job!==run)return;
 if(outcome){if(field.value===previousValue){field.value=outcome.plate;field.dispatchEvent(new Event('input',{bubbles:true}));status('Plaque remplie automatiquement : '+outcome.plate+'. Vérifiez les lettres et les chiffres avant de valider.');field.scrollIntoView({block:'nearest',behavior:'smooth'})}else status('Lecture terminée. Votre saisie manuelle a été conservée.')}
 else status('Aucun numéro suffisamment lisible. Reprenez une photo de près, avec la plaque entière et sans reflet. Vous pouvez aussi saisir le numéro.');
 }catch(error){if(job===run){status(error.message||'Lecture impossible. Reprenez une photo ou saisissez la plaque.');if(worker)worker.terminate().catch(()=>{});worker=null;initializing=null}}
 finally{clearTimeout(timer);if(bitmap)bitmap.close();if(job===run){submit.disabled=false;document.getElementById('photo').disabled=false;document.getElementById('photo').value=''}}
 }
 return {scan,cancel};
})();
if(typeof module!=='undefined')module.exports={plateCandidates};
