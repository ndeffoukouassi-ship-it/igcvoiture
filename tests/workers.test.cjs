const test=require('node:test'),assert=require('node:assert/strict');
const {workerTotals}=require('../public/workers.js');
const {financeSummary}=require('../public/finance-core.js');
const {validateBackup}=require('../public/import.js');
test('only completed cars earn wages, including gifts; other workers are isolated',()=>{
 const tickets=[{workerId:'a',workerFee:500,status:'Terminé'},{workerId:'a',workerFee:700,status:'Terminé',workerPaidAt:1},{workerId:'a',workerFee:500,status:'En cours'},{workerId:'a',workerFee:500,status:'Terminé',gift:true},{workerId:'b',workerFee:900,status:'Terminé'}];
 assert.deepEqual(workerTotals(tickets,'a'),{count:3,due:1000,paid:700});
});
test('recorded worker payment is counted once as a payroll expense',()=>{
 const expenses=[{amount:500,date:'2026-11-21',category:'Salaires / primes'}];
 const s=financeSummary([],expenses,'month','2026-11-21');assert.equal(s.spent,500);assert.equal(s.balance,-500);
});
test('backup retains worker rates and rejects inconsistent assignments',()=>{
 const id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';const input={center:'Lavage',services:[{name:'Complet',price:3000}],tickets:[],workers:[{id,name:'Koffi',rate:500,active:true}]};
 assert.deepEqual(validateBackup(structuredClone(input)).workers,input.workers);
 input.workers[0].rate=-1;assert.throws(()=>validateBackup(input),/Laveur invalide/);
});
