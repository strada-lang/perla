class Counter { constructor(){this.count=0;} increment(){this.count++;} get(){return this.count;} }
const it=5000000; const c=new Counter();
for(let i=0;i<it;i++){ c.increment(); }
console.log("oop: "+it+" method calls, count="+c.get());
