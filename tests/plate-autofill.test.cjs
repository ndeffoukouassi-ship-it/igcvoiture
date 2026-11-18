const {test}=require('node:test');const a=require('node:assert/strict');const vm=require('node:vm');const fs=require('node:fs');
function fixture(recognize){
 let inputEvents=0;const elements={plate:{value:'',dispatchEvent(){inputEvents++},scrollIntoView(){}},ocr:{textContent:''},photo:{disabled:false,value:'file'},preview:{hidden:true},submit:{disabled:false}};elements.ticketForm={querySelector:()=>elements.submit};
 const worker={setParameters:async()=>{},recognize,terminate:async()=>{}};const tesseract={createWorker:async()=>worker};
 const document={getElementById:id=>elements[id],createElement:tag=>({width:0,height:0,getContext:()=>({fillRect(){},drawImage(){},getImageData(x,y,width,height){return {width,height,data:new Uint8ClampedArray(width*height*4)}}})})};
 const context=vm.createContext({document,window:{Tesseract:tesseract},Tesseract:tesseract,URL:{createObjectURL:()=>'/photo',revokeObjectURL(){}},createImageBitmap:async()=>({width:1000,height:280,close(){}}),setTimeout,clearTimeout,Event,location:{origin:'https://test.invalid'}});
 vm.runInContext(fs.readFileSync('public/plate-ocr.js','utf8'),context);
 return {elements,events:()=>inputEvents,scan:()=>vm.runInContext('PlateScanner.scan({size:1000})',context),cancel:()=>vm.runInContext('PlateScanner.cancel()',context)};
}
test('photo OCR automatically fills the plate and notifies loyalty input',async()=>{const f=fixture(async()=>({data:{text:'AB 123 CD',confidence:94}}));await f.scan();a.equal(f.elements.plate.value,'AB123CD');a.equal(f.events(),1);a.equal(f.elements.submit.disabled,false);a.match(f.elements.ocr.textContent,/automatiquement/)});
test('closing a scan prevents late OCR results entering the next vehicle',async()=>{let finish;const f=fixture(()=>new Promise(resolve=>finish=resolve));const scan=f.scan();while(!finish)await new Promise(resolve=>setImmediate(resolve));f.cancel();f.elements.plate.value='OTHER123';finish({data:{text:'AB 123 CD',confidence:94}});await scan;a.equal(f.elements.plate.value,'OTHER123');a.equal(f.events(),0)});
test('manual typing during OCR is preserved',async()=>{let finish;const f=fixture(()=>new Promise(resolve=>finish=resolve));const scan=f.scan();while(!finish)await new Promise(resolve=>setImmediate(resolve));f.elements.plate.value='MANUAL123';finish({data:{text:'AB 123 CD',confidence:94}});await scan;a.equal(f.elements.plate.value,'MANUAL123')});
