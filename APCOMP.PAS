{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}
program apcomp;

uses crt,dos,utility;

type
 apc=record
  filecrc:word;
  attr:byte;
  time:longint;
  size:longint;
  name:string[12];
 end;
 data=array [1..2500] of apc;
 dptr=^data;

var
 file1,file2:file of apc;
 o:text;
 s,s1,s2,ofname,wname,exlist:string;
 p1,p2:dptr;
 han1,han2,loop:word;
 inner,outer,len1,len2,maxlen:longint;
 ioerror:integer;
 dt:datetime;
 m1,m2:apc;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 nomem,display:boolean;
 
{**************************************************************************}

function nproc(s:string):string;

var
 temp:string;

begin
 temp:=s;
 if pos('.',temp)=0 then temp:=temp+'.   ';
 while length(temp)-pos('.',temp)<3 do temp:=temp+' ';
 while length(temp)<13 do temp:=' '+temp;
 nproc:=temp;
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

begin
 writeln(#10' ApComp - ''Footprint'' File Compare Utility v2.15 (c) 1993 M E Ralphson');
 writeln;

 if paramcount<2 then begin
  writeln('Usage: ApComp <datafile1> <datafile2> [<output file>] [/Xexc.list]');
  writeln;
  writeln('   Eg: ApComp 5001.APC 5002.APC apcomp.txt /x.log.bat');
  writeln;
  writeln('Default extension for datafiles is .APC, use /X to exclude extensions');
  writeln('from the comparison process.');
  exit;
 end;
 
 nomem:=false;
 if mem_avail<3750 then nomem:=true else han1:=mem_alloc(3750);
 if mem_avail<3750 then nomem:=true else han2:=mem_alloc(3750);

 if nomem then begin
  writeln('Not enough memory for buffers!');
  exit;
 end;
 
 display:=false;
 ofname:='CON';
 exlist:='';
 for loop:=3 to paramcount do begin
  s:=ucase(paramstr(loop));
  if pos('/X',s)=1 then begin
   exlist:=s;
   delete(exlist,1,2);
  end else begin
   ofname:=s;
   display:=true;
  end; 
 end;
 
 assign(o,ofname);
 rewrite(o);
 
 p1:=ptr(han1,0);
 p2:=ptr(han2,0);

 s1:=paramstr(1);
 if pos('.',s1)=0 then s1:=s1+'.APC';
 s2:=paramstr(2);
 if pos('.',s2)=0 then s2:=s2+'.APC';
 
 s1:=fexpand(s1);
 s2:=fexpand(s2);

 assign(file1,s1);
 assign(file2,s2);
 reset(file1);
 reset(file2);
 
 if ioresult<>0 then begin
  writeln('Error opening files!');
  exit;
 end;
 
 write('Loading..');
 len1:=filesize(file1);
 len2:=filesize(file2);
 maxlen:=len1+len2;
 for loop:=1 to len1 do read(file1,p1^[loop]);
 write('.');
 for loop:=1 to len2 do read(file2,p2^[loop]);
 write('. Sorting..');
 apsort(p1,len1);
 write('.');
 apsort(p2,len2);
 writeln('. ',maxlen,' files'#10);

 inner:=1;

 for outer:=1 to len1 do begin
  m1:=p1^[outer];
  repeat
   if display then write('Processed ',round((outer/maxlen)*100),'%'#13);
   m2:=p2^[inner];
   inc(inner);
  until (inner>len2) or (m2.name>=m1.name);
  
  fsplit(m1.name,dir,name,ext);
  wname:=nproc(m1.name);

  if pos(ext,exlist)>0 then else
  if m1.name<>m2.name then writeln(o,wname,' is missing from the Second footprint') else
  if m1.filecrc<>m2.filecrc then begin
   write(o,wname,' CRC detected changes, ');
   if m1.time<m2.time then write(o,'Second') else write(o,'First');
   writeln(o,' file is more recent');
  end else
  if (m1.filecrc=m2.filecrc) and (m1.filecrc<>0) then else
  if m1.time<m2.time  then writeln(o,wname,' First footprint version is earlier than Second') else
  if m1.time>m2.time  then writeln(o,wname,' First footprint version is later than Second') else
  if m1.size<>m2.size then writeln(o,wname,' file sizes are different');

  if m1.name<>m2.name then inner:=1;
 end;

 inner:=1;

 for outer:=1 to len2 do begin
  m2:=p2^[outer];
  repeat
   if display then write('Processed ',round(((outer+len1)/maxlen)*100),'%'#13);
   m1:=p1^[inner];
   inc(inner);
  until (inner>len1) or (m1.name>=m2.name);
  
  fsplit(m2.name,dir,name,ext);
  wname:=nproc(m2.name);
  
  if m1.name<>m2.name then begin
   if pos(ext,exlist)=0 then writeln(o,wname,' is missing from the First footprint');
   inner:=1;
  end;
 end;

 close(o);
 close(file1);
 close(file2);
 
 if display then writeln;

end.
