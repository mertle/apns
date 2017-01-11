{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}
program apcheck;

uses crt,dos,utility;

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

{$I truename.inc}
{$I apcrc.inc}

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
 fast:boolean;
 
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

var
 sticky:byte;

begin
 checksnow:=false;
 textattr:=7;
 clrscr;
 fast:=false;
 writeln(#10' ApCheck - Program / Data File Integrity Checker v1.40 (c) 1992 M E Ralphson');
 writeln;

 if paramcount<2 then begin
  writeln('Usage: ApCheck <datafile> [/Q] <filespec> [<filespec>...]');
  exit;
 end;

 ofname:=paramstr(1);
 ofname:=fexpand(ofname);

 assign(outfile,ofname);
 reset(outfile);
 seek(outfile,filesize(outfile));
 if ioresult<>0 then begin
  rewrite(outfile);
  if ioresult<>0 then begin
   writeln('Could not access ',ofname);
   exit;
  end;
 end;

 writeln('Processing: ');
 writeln;
 writeln('  File-Name      Size    Attr.     Date      Time     CRC');
 writeln('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');

 filemode:=64;
 nofiles:=0;
 nobytes:=0;
 for outer:=2 to paramcount do begin
  window(1,1,80,25);
  gotoxy(13,4);
  param:=paramstr(outer);
  param:=ucase(param);
  if param='/Q' then fast:=true else begin
   param:=fexpand(param);
   fsplit(param,dir,name,ext);
   write(truename(param));
   clreol;
   window(1,8,80,25);
   clrscr;
   fillchar(sr,sizeof(sr),#0);
   findfirst(param,realfile,sr);
   while doserror=0 do begin
    inc(nofiles);
    inc(nobytes,sr.size);
    write(sr.name:12);
    gotoxy(13,wherey);
    write(sr.size:10,'  ');
 
    s:='RHSVDA';
    b:=1;
    for inner:=1 to 6 do begin
     if sr.attr and b<>b then s[inner]:='ú';
     b:=b shl 1;
    end;
    write(s,'  ');
 
    unpacktime(sr.time,dt);
    with dt do write(pad(day),'/',pad(month),'/',pad(year),' ',pad(hour),':',
     pad(min),':',pad(sec),'  ');
 
    crc:=0;
    if not fast then begin 
     assign(f,dir+sr.name);
     reset(f,1);
     ioerror:=ioresult;
     if ioerror<>0 then writeln(' [IO Error ',ioerror,']') else begin
      crc:=0;
      repeat
       blockread(f,buffer,50000,bytesread);
       crc16(crc,buffer,bytesread);
      until bytesread<50000;
      close(f);
     end;
    end;
    write(hex(crc),'h');
    if fast then write(#13) else writeln;

    mr.filecrc:=crc;
    move(sr.attr,mr.attr,22);
    for loop:=succ(length(mr.name)) to 12 do mr.name[loop]:=' ';
    write(outfile,mr);

    findnext(sr);

   end;
   writeln;
  end; 
 end;

 close(outfile);
 window(1,4,80,25);
 clrscr;
 writeln('Processed ',nofiles,' files, totalling ',nobytes,' bytes.');
end.
