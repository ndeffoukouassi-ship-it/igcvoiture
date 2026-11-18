import {build} from 'esbuild';
import {mkdir,cp,writeFile} from 'node:fs/promises';
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_PUBLISHABLE_KEY;
if(!url||!key)throw Error('SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY sont obligatoires');
if(!/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(url))throw Error('URL Supabase invalide');
await mkdir('build',{recursive:true});await cp('public','build',{recursive:true});
await build({stdin:{contents:"import { createClient } from '@supabase/supabase-js'; window.createSupabaseClient=createClient;",resolveDir:process.cwd()},bundle:true,minify:true,format:'iife',platform:'browser',outfile:'build/vendor.js'});
await writeFile('build/config.js','window.AUTOWASH_CONFIG='+JSON.stringify({url,key})+';\n');
// Version assets so a deployment never mixes old scripts with new markup.
const {readFile}=await import('node:fs/promises');
const {createHash}=await import('node:crypto');
let html=await readFile('build/index.html','utf8');
const assets=[...html.matchAll(/(?:src|href)="([^"?]+\.(?:js|css))"/g)].map(m=>m[1]);
for(const asset of new Set(assets)){
 const hash=createHash('sha256').update(await readFile('build/'+asset)).digest('hex').slice(0,12);
 html=html.replaceAll('"'+asset+'"','"'+asset+'?v='+hash+'"');
}
await writeFile('build/index.html',html);
