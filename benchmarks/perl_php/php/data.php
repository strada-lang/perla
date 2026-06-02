<?php $it=500000; $a=array();
for($i=0;$i<$it;$i++){ $a[]=$i*$i; }
$sum=0; foreach($a as $v){ $sum+=$v; }
$f=array();
for($i=0;$i<$it;$i++){ $k="key_".($i%100); if(isset($f[$k]))$f[$k]+=1; else $f[$k]=1; }
echo "data: $it, sum=$sum, keys=".count($f)."\n";
