const it=500000; const a=[];
for(let i=0;i<it;i++){ a.push(i*i); }
let sum=0; for(const v of a){ sum+=v; }
const f={};
for(let i=0;i<it;i++){ const k="key_"+(i%100); if(k in f){f[k]+=1;}else{f[k]=1;} }
console.log("data: "+it+", sum="+sum+", keys="+Object.keys(f).length);
