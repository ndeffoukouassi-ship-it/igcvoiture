import {createHash} from 'node:crypto';
import {build} from 'esbuild';
import {mkdir,cp,writeFile,readFile} from 'node:fs/promises';
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_PUBLISHABLE_KEY;
if(!url||!key)throw Error('SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY sont obligatoires');
if(!/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(url))throw Error('URL Supabase invalide');
await mkdir('build/ocr/core',{recursive:true});await mkdir('build/ocr/lang',{recursive:true});await cp('node_modules/tesseract.js/dist/tesseract.min.js','build/ocr/tesseract.min.js');await cp('node_modules/tesseract.js/dist/worker.min.js','build/ocr/worker.min.js');await cp('node_modules/tesseract.js-core','build/ocr/core',{recursive:true,filter:source=>!source.endsWith('package.json')});await cp('node_modules/@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz','build/ocr/lang/eng.traineddata.gz');await mkdir('build',{recursive:true});await cp('public','build',{recursive:true});
await build({stdin:{contents:"import { createClient } from '@supabase/supabase-js'; window.createSupabaseClient=createClient;",resolveDir:process.cwd()},bundle:true,minify:true,format:'iife',platform:'browser',outfile:'build/vendor.js'});
await writeFile('build/config.js','window.AUTOWASH_CONFIG='+JSON.stringify({url,key,appVersion:createHash('sha256').update(await readFile('public/app.js')).digest('hex').slice(0,12)})+';\n');
// Version assets so a deployment never mixes old scripts with new markup.
let html=await readFile('build/index.html','utf8');
const assets=[...html.matchAll(/(?:src|href)="([^"?]+\.(?:js|css))"/g)].map(m=>m[1]);
for(const asset of new Set(assets)){
 const hash=createHash('sha256').update(await readFile('build/'+asset)).digest('hex').slice(0,12);
 html=html.replaceAll('"'+asset+'"','"'+asset+'?v='+hash+'"');
}
await writeFile('build/index.html',html);
