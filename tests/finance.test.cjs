const {strict:a}=require('node:assert');const {periodBounds:p,financeSummary:f}=require('../public/finance-core.js');
a.deepEqual(p('week','2027-01-01'),{start:'2026-12-28',end:'2027-01-04'});
a.deepEqual(p('month','2028-02-29'),{start:'2028-02-01',end:'2028-03-01'});
a.deepEqual(p('year','2026-12-31'),{start:'2026-01-01',end:'2027-01-01'});
const ts=[{created:Date.parse('2026-10-31'),paidAt:Date.parse('2026-11-02'),payment:'Wave',amount:3000},{created:Date.parse('2026-11-02'),payment:'',amount:1500},{created:Date.parse('2026-11-02'),gift:true,payment:'Offert',paidAt:null,amount:0},{created:Date.parse('2026-11-30'),paidAt:Date.parse('2026-12-01'),payment:'Espèces',amount:5000}];
let s=f(ts,[{date:'2026-11-15',amount:1000},{date:'2026-12-01',amount:500}],'month','2026-11-18');a.equal(s.revenue,3000);a.equal(s.spent,1000);a.equal(s.balance,2000);a.equal(s.outstanding,1500);a.equal(s.visits.length,3);a.equal(s.receipts.length,1);
s=f([], [{date:'2026-11-18',amount:2000}], 'day','2026-11-18');a.equal(s.balance,-2000);a.equal(f([],[],'year','2026-11-18').balance,0);console.log('Bilans : 11 vérifications réussies');
