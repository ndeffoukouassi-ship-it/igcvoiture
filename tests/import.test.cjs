const {strict:a}=require('node:assert');const {validateBackup:v}=require('../public/import.js');
const data={center:'TEST',services:[{name:'Lavage',price:1500}],tickets:[],expenses:[]};a.equal(v(structuredClone(data)).center,'TEST');a.throws(()=>v({...data,services:[]}));a.throws(()=>v({...data,tickets:[{id:'" onclick="evil()'}]}));a.throws(()=>v({...data,services:[{name:'Lavage',price:-1}]}));
