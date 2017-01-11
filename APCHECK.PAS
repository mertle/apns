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
 buffer=array [1..50000] of byte;

{$I apcrc.inc}

var
 handle,crc,loop,bytesread:word;
 outfile:file of apc;
 ofname,param,s:string;
 buf:^buffer;
 ioerror:integer;
 dt:datetime;
 nofiles,nobytes:longint;
 f:file;
 sr:searchrec;
 mr:apc;
 inner,outer,b:byte;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 fast:boolean;
 
{**************************************************************************} 

begin
 checksnow:=false;
 textattr:=7;
 clrscr;
 fast:=false;
 writeln(#10' ApCheck - ''Footprint'' File Creation Utility v2.15 (c) 1993 M E Ralphson');
 writeln;

 if paramcount<2 then begin
  writeln('Usage: ApCheck <datafile> [/Q] <filespec> [<filespec>...]');
  exit;
 end;

 handle:=mem_alloc(3125);
 buf:=ptr(handle,0);
 
 ofname:=paramstr(1);
 if pos('.',ofname)=0 then ofname:=ofname+'.APC';
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
   write(param);
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
    with dt do write(itos(day,2),'/',itos(month,2),'/',itos(year,2),' ',
                     itos(hour,2),':',itos(min,2),':',itos(sec,2),'  ');
 
    crc:=0;
    if not fast then begin 
     assign(f,dir+sr.name);
     reset(f,1);
     ioerror:=ioresult;
     if ioerror<>0 then writeln(' [IO Error ',ioerror,']') else begin
      crc:=0;
      repeat
       blockread(f,buf^,50000,bytesread);
       crc16(crc,buf^,bytesread);
      until bytesread<50000;
      close(f);
     end;
    end;
    write(w2hexs(crc),'h');
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
