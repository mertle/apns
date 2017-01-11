{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}
program apcheck;

uses crt,dos;

{$I crc16.inc}

const
 realfile=$27;

type
 apc=record
  filecrc:word;
  filechk:byte;
  unused:array [1..18] of byte;
  attr:byte;
  time:longint;
  size:longint;
  name:string[12];
 end;
 ss=string[4];

var
 sr:searchrec;
 mr:apc;
 outfile:file of apc;
 ofname,param,s:string;
 crc,loop:word;
 inner,outer,checksum,b:byte;
 buffer:array [1..50000] of byte;
 f:file;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 bytesread:word;
 ioerror:integer;
 dt:datetime;
 nofiles,nobytes:longint;

function pad(w:word):ss;

var
 temp:ss;

begin
 str(w:2,temp);
 if temp[1]=' ' then temp[1]:='0';
 pad:=temp;
end;

function hex(w:word):ss;

const
 hs:array [0..15] of char='0123456789ABCDEF';

begin
 hex:=hs[hi(w) div 16]+hs[hi(w) mod 16]+hs[lo(w) div 16]+hs[lo(w) mod 16];
end;

var
 sticky:byte;

begin
 textattr:=7;
 clrscr;
 writeln(#10' ApCheck - Program / Data File Integrity Checker v1.00 (c) 1991 M. E. Ralphson');
 writeln;

 if paramcount<2 then begin
  writeln('Usage: ApCheck <datafile> <filespec> [<filespec>...]');
  exit;
 end;

 ofname:=paramstr(1);
 ofname:=fexpand(ofname);

 assign(outfile,ofname);
 rewrite(outfile);
 if ioresult<>0 then begin
  writeln('Could not access ',ofname);
  exit;
 end;

 writeln('Processing: ');
 writeln;
 writeln('  File-Name      Size    Attr.     Date      Time     CRC');
 writeln('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');

 filemode:=0;
 nofiles:=0;
 nobytes:=0;
 for outer:=2 to paramcount do begin
  window(1,1,80,25);
  gotoxy(13,4);
  param:=paramstr(outer);
  param:=fexpand(param);
  fsplit(param,dir,name,ext);
  write(param);
  clreol;
  window(1,8,80,25);
  clrscr;
  fillchar(sr,sizeof(sr),#0);
  findfirst(param,realfile,sr);
  while doserror=0 do begin
   inc(nofiles);
   inc(nobytes,sr.size);
   write(sr.name);
   gotoxy(13,wherey);
   write(sr.size:10,'  ');

   s:='RHSVDA';
   b:=1;
   for inner:=1 to 6 do begin
    if sr.attr and b<>b then s[inner]:='ú';
    b:=b*2;
   end;
   write(s,'  ');

   unpacktime(sr.time,dt);
   with dt do write(pad(day),'/',pad(month),'/',pad(year),' ',pad(hour),':',
    pad(min),':',pad(sec),'  ');

   mr:=apc(sr);
   fillchar(mr,21,#0);
   assign(f,dir+sr.name);
   reset(f,1);
   ioerror:=ioresult;
   if ioerror<>0 then writeln(' [IO Error ',ioerror,']') else begin
    crc:=0;
    checksum:=0;
    sticky:=sr.size div 50000;
    if sr.size mod 50000>0 then inc(sticky);
    if sticky>26 then sticky:=26;
    for loop:=1 to sticky do write('ş');
    gotoxy(54,wherey);
    repeat
     textattr:=4;
     write('ş');
     textattr:=7;
     gotoxy(pred(wherex),wherey);

     blockread(f,buffer,50000,bytesread);
     for loop:=1 to bytesread do crc16(checksum,crc,buffer[loop]);

     write('ş');
     if wherex=80 then gotoxy(54,wherey);
    until bytesread<50000;
    close(f);
    mr.filecrc:=crc;
    mr.filechk:=checksum;
    write(outfile,mr);
    gotoxy(54,wherey);
    clreol;
    writeln(hex(crc),'h');
   end;
   fillchar(sr.attr,22,#0);
   findnext(sr);
  end;
  writeln;
 end;

 close(outfile);
 window(1,4,80,25);
 clrscr;
 writeln('Processed ',nofiles,' files, totalling ',nobytes,' bytes.');
end.