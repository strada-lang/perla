const it=1000000; let r="";
for(let i=0;i<it;i++){ let s="Hello, World! "+i; s=s.replace("World","Perl"); if(i===it-1) r=s; }
console.log("strings: "+it+", last="+r);
