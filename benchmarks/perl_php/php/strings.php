<?php $it=1000000; $r="";
for($i=0;$i<$it;$i++){ $s="Hello, World! ".$i; $s=preg_replace('/World/','Perl',$s,1); if($i==$it-1)$r=$s; }
echo "strings: $it, last=$r\n";
