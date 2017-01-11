type
 idxbuf=array [1..32767] of word;
 msgbuf=array [0..65534] of byte;

var
 msgdata:^msgbuf; 
 idxdata:^idxbuf;
 
procedure messages; external;
procedure txtindex; external; 
 
procedure initmsg;

begin
 msgdata:=@messages;
 idxdata:=@txtindex;
end; 

function msg(n:word):string;

var
 s:string;

begin
 move(msgdata^[idxdata^[n]],s,256);
 msg:=s;
end;
