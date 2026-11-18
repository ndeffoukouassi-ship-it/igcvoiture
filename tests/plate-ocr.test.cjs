const {strict:a}=require('node:assert');const {plateCandidates:f}=require('../public/plate-ocr.js');
a.equal(f('AB 123 CD')[0].plate,'AB123CD');a.equal(f('1234 AB 01')[0].plate,'1234AB01');a.equal(f("CÔTE D’IVOIRE\nAB 123 CD")[0].plate,'AB123CD');a.equal(f('CAR WASH\n2026\nAB-123-CD')[0].plate,'AB123CD');a.equal(f('COTE DIVOIRE').length,0);a.equal(f('123456').length,0);a.equal(f('AB O12 CD')[0].plate,'ABO12CD');

const {findYellowPlate,choosePlateResult}=require('../public/plate-ocr.js');
const image={width:100,height:60,data:new Uint8ClampedArray(100*60*4)};for(let y=20;y<35;y++)for(let x=10;x<85;x++){const i=(y*100+x)*4;image.data.set([200,180,20,255],i)}const box=findYellowPlate(image);a.equal(box.x,10);a.equal(box.y,20);a.equal(box.width,75);
a.equal(choosePlateResult([{plate:'1D179535',confidence:20},{plate:'D179535',confidence:42,region:true},{plate:'D179535',confidence:0,region:true}]).plate,'D179535');
a.equal(choosePlateResult([{plate:'1D179535',confidence:40}]).reliable,false);
