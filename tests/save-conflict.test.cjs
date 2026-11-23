const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
test('stale save sends one RPC, blocks further saves, and never reports success',async()=>{
 const els=new Map();const el=id=>{if(!els.has(id))els.set(id,{hidden:false,textContent:'',setAttribute(){},append(){}});return els.get(id)};
 let calls=0,options;
 const client={auth:{getSession:async()=>({data:{session:true}}),getUser:async()=>({data:{user:{id:'owner',email:'test@example.invalid'}}}),onAuthStateChange(){}},rpc:async name=>{
 if(name==='autowash_is_platform_admin')return {data:false};
 if(name==='autowash_workspace')return {data:{owner_id:'owner',role:'owner',revision:2,state:{expenses:[]}}};
 if(name==='autowash_save_workspace'){calls++;return {error:{code:'PT409',message:'CONCURRENT_EDIT'}}}
 }};
 const context={window:{AUTOWASH_CONFIG:{url:'https://example.supabase.co',key:'public'}},document:{getElementById:el,createElement:()=>({})},location:{hash:'',search:'',pathname:'/'},sessionStorage:{getItem:()=>null},URLSearchParams,createSupabaseClient:(u,k,o)=>{options=o;return client},structuredClone,console};
 vm.createContext(context);vm.runInContext(fs.readFileSync('public/cloud.js','utf8'),context);
 await new Promise(resolve=>setImmediate(resolve));
 assert.equal(options.db.retry,false);
 await assert.rejects(context.window.Cloud.save({expenses:[]}),/Actualisez/);
 await assert.rejects(context.window.Cloud.save({expenses:[]}),/Actualisez/);
 assert.equal(calls,1);assert.equal(el('cloudStatus').textContent,'Échec de l’enregistrement');assert.equal(el('cloudSaving').hidden,true);
});
