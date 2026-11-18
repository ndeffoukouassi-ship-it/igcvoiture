function periodBounds(kind, anchor){
 const d=new Date(anchor+'T00:00:00Z');if(!Number.isFinite(+d))throw Error('Date invalide');
 let start=new Date(d),end=new Date(d);
 if(kind==='week'){start.setUTCDate(start.getUTCDate()-((start.getUTCDay()+6)%7));end=new Date(start);end.setUTCDate(end.getUTCDate()+7)}
 else if(kind==='month'){start=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth(),1));end=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,1))}
 else if(kind==='year'){start=new Date(Date.UTC(d.getUTCFullYear(),0,1));end=new Date(Date.UTC(d.getUTCFullYear()+1,0,1))}
 else end.setUTCDate(end.getUTCDate()+1);
 return {start:start.toISOString().slice(0,10),end:end.toISOString().slice(0,10)};
}
function financeSummary(tickets,expenses,kind,anchor){
 const bounds=periodBounds(kind,anchor);const inside=d=>d>=bounds.start&&d<bounds.end;
 const dateKey=t=>new Date(t).toISOString().slice(0,10);
 const receipts=tickets.filter(t=>!t.gift&&t.payment&&t.paidAt!=null&&Number(t.amount)>0&&inside(dateKey(t.paidAt)));
 const costs=expenses.filter(e=>inside(e.date));const visits=tickets.filter(t=>inside(dateKey(t.created)));
 const revenue=receipts.reduce((s,t)=>s+Number(t.amount),0),spent=costs.reduce((s,e)=>s+Number(e.amount),0);
 return {...bounds,receipts,costs,visits,revenue,spent,balance:revenue-spent,outstanding:visits.filter(t=>!t.payment).reduce((s,t)=>s+Number(t.amount),0)};
}
if(typeof module!=='undefined')module.exports={periodBounds,financeSummary};
