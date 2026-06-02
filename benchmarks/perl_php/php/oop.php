<?php class Counter{ public $count=0; function increment(){$this->count++;} function get(){return $this->count;} }
$it=5000000; $c=new Counter();
for($i=0;$i<$it;$i++){ $c->increment(); }
echo "oop: $it method calls, count=".$c->get()."\n";
