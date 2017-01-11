{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 4096,0,66000}

program encryptor;

uses dos,random6;

{$I lastrev.inc}

const
 version='2.15';

type
 buffer=array [1..65000] of byte;

var
 s,filename,outname:string;
 ftime:longint;
 loop:word;
 key:array [1..128] of byte;
 keypos,keylen:byte;
 f,o:file;
 flen,bytesread,next,readpos,writepos:longint;
 buf:^buffer;

begin
 writeln(#10'Encrypt v'+version+' ('+lastrev+'), Copyright (c) 1991,93 Michael E Ralphson');
 if paramcount<2 then writeln(#10'Usage: Encrypt <filename> <key>') else begin
  filename:=paramstr(1);
  assign(f,filename);
  reset(f,1);
  getftime(f,ftime);
  if ioresult<>0 then writeln(#10'Error reading ',filename) else begin

   if maxavail<sizeof(buffer) then begin
    writeln(#10'Not enough memory for buffer');
    exit;
   end;

   getmem(buf,sizeof(buffer));
   s:=paramstr(2);
   if length(s) mod 2=0 then s:='~'+s;
   keylen:=length(s);
   for loop:=1 to keylen do
    key[loop]:=255-ord(s[succ(keylen-loop)]) xor ord(s[keylen]);
   flen:=filesize(f);
   bytesread:=0;
   keypos:=1;
   repeat
    next:=flen-bytesread;
    if next>65000 then next:=65000;
    writepos:=filepos(f);
    blockread(f,buf^,next);
    for loop:=1 to next do begin
     buf^[loop]:=buf^[loop] xor key[keypos];
     key[keypos]:=loop xor random(256);
     inc(keypos);
     if keypos>keylen then keypos:=1;
    end;
    readpos:=filepos(f);
    seek(f,writepos);
    blockwrite(f,buf^,next);
    inc(bytesread,next);
    seek(f,readpos);
   until bytesread=flen;
   setftime(f,ftime);
   close(f);
   freemem(buf,sizeof(buffer));
  end;
 end;
end.
