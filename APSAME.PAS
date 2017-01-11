{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,130000}
program apcomp;

uses dos;

const
 realfile=$27;

type
 apc=record
  filecrc:word;
  attr:byte;
  time:longint;
  size:longint;
  name:string[12];
 end;
 ss=string[4];

type
 data=array [1..2500] of apc;
 dptr=^data;

var
 sr:searchrec;
 m1,m2:apc;
 file1,file2:file of apc;
 param,s1,s2:string;
 p1,p2:dptr;
 loop:word;
 inner,outer,len1,len2,z1,z2:longint;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 ioerror:integer;
 dt:datetime;
 
{**************************************************************************} 

function pad(w:word):ss;

var
 temp:ss;

begin
 str(w:2,temp);
 if temp[1]=' ' then temp[1]:='0';
 pad:=temp;
end;

{**************************************************************************} 

function hex(w:word):ss;

const
 hs:array [0..15] of char='0123456789ABCDEF';

begin
 hex:=hs[hi(w) div 16]+hs[hi(w) mod 16]+hs[lo(w) div 16]+hs[lo(w) mod 16];
end;

{**************************************************************************}

procedure apsort(sp:dptr;max:longint);

 procedure qsort(l,r:integer);

 var
  i,j:integer;
  x,y:apc;

 begin
  i:=l;
  j:=r;
  x:=sp^[(l+r) DIV 2];
  repeat
   while sp^[i].name<x.name do inc(i);
   while x.name<sp^[j].name do dec(j);
   if i<=j then begin
    y:=sp^[i];
    sp^[i]:=sp^[j];
    sp^[j]:=y;
    inc(i);
    dec(j);
   end;
  until i>j;
  if l<j then qsort(l,j);
  if i<r then qsort(i,r);
 end;
 
begin
 qsort(1,max);
end;

{**************************************************************************}

var
 sticky:byte;
 nomem:boolean;

begin
 writeln(#10' ApSame - ''Footprint'' File Compare Utility v1.40 (c) 1992 M E Ralphson');
 writeln;

 if paramcount<2 then begin
  writeln('Usage: ApSame <datafile1> <datafile2>');
  exit;
 end;

 nomem:=false;
 if maxavail<60000 then nomem:=true else getmem(p1,60000);
 if maxavail<60000 then nomem:=true else getmem(p2,60000);
 
 if nomem then begin
  writeln('Not enough memory for buffers!');
  exit;
 end;

 s1:=paramstr(1);
 s1:=fexpand(s1);
 s2:=paramstr(2);
 s2:=fexpand(s2);

 assign(file1,s1);
 assign(file2,s2);
 reset(file1);
 reset(file2);
 
 if ioresult<>0 then begin
  writeln('Error opening files!');
  exit;
 end;
 
 len1:=filesize(file1);
 len2:=filesize(file2);

 write('Loading.');
 for loop:=1 to len1 do read(file1,p1^[loop]);
 write('.');
 for loop:=1 to len2 do read(file2,p2^[loop]);
 write('. Sorting.');
 apsort(p1,len1);
 write('.');
 apsort(p2,len2);
 writeln('. ',len1+len2,' files'#10);

 inner:=1;

 for outer:=1 to len1 do begin
  m1:=p1^[outer];
  repeat
   m2:=p2^[inner];
   inc(inner);
  until (inner>len2) or (m2.name>=m1.name);

  if (m1.filecrc=m2.filecrc) and (m1.filecrc<>0) then writeln(m1.name:13,' is identical');

  if m1.name<>m2.name then inner:=1;
 end;

 inner:=1;

 for outer:=1 to len2 do begin
  m2:=p2^[outer];
  repeat
   m1:=p1^[inner];
   inc(inner);
  until (inner>len1) or (m1.name>=m2.name);
  
  if m1.name<>m2.name then begin
{   writeln(m2.name:13,' is missing from the first footprint');}
   inner:=1;
  end;
 end;

 close(file1);
 close(file2);

end.
