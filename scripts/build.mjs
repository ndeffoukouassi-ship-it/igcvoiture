import {build} from 'esbuild';
import {mkdir,cp,writeFile} from 'node:fs/promises';
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_PUBLISHABLE_KEY;
if(!url||!key)throw Error('SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY sont obligatoires');
if(!/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(url))throw Error('URL Supabase invalide');
await mkdir('build',{recursive:true});await cp('public','build',{recursive:true});
await build({stdin:{contents:"import { createClient } from '@supabase/supabase-js'; window.createSupabaseClient=createClient;",resolveDir:process.cwd()},bundle:true,minify:true,format:'iife',platform:'browser',outfile:'build/vendor.js'});
await writeFile('build/config.js','window.AUTOWASH_CONFIG='+JSON.stringify({url,key})+';\n');
