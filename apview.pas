{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}
program apview;

uses crt,dos,utility;

type
 apc=record
  filecrc:word;
  attr:byte;
  time:longint;
  size:longint;
  name:string[12];
 end;

var
 ifname,param,s:string;
 infile:file of apc;
 f:text;
 dt:datetime;
 nofiles,nobytes:longint;
 mr:apc;
 loop,b:byte;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 
{**************************************************************************} 

begin
 checksnow:=false;
 textattr:=7;
 clrscr;
 writeln(#10' ApView - ''FootPrint'' File View / Print Utility v2.15 (c) 1993 M E Ralphson');
 writeln;

 if paramcount<1 then begin
  writeln('Usage: ApView <datafile> [<output file>]');
  exit;
 end;

 ifname:=paramstr(1);
 ifname:=fexpand(ifname);

 assign(infile,ifname);
 reset(infile);
 if ioresult<>0 then begin
  writeln('Could not access ',ifname);
  exit;
 end;
 
 param:=ucase(paramstr(2));
 assign(f,param);
 rewrite(f);
 if ioresult<>0 then begin
  writeln('Could not access ',param);
  exit;
 end;

 writeln('Processing: ',ifname);
 writeln;
 writeln('  File-Name      Size    Attr.     Date      Time     CRC');
 writeln('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');

 nofiles:=0;
 nobytes:=0;
 window(1,8,80,25);
 clrscr;
 repeat
  read(infile,mr);
  inc(nofiles);
  inc(nobytes,mr.size);
  write(mr.name:12);
  gotoxy(13,wherey);
  write(mr.size:10,'  ');

  s:='RHSVDA';
  b:=1;
  for loop:=1 to 6 do begin
   if mr.attr and b<>b then s[loop]:='ú';
   b:=b shl 1;
  end;
  write(s,'  ');

  unpacktime(mr.time,dt);
  with dt do write(itos(day,2),'/',itos(month,2),'/',itos(year,2),' ',
                   itos(hour,2),':',itos(min,2),':',itos(sec,2),'  ');
  writeln(w2hexs(mr.filecrc),'h');
 until eof(infile);
 writeln;
 close(infile);
 window(1,4,80,25);
 clrscr;
 writeln('Processed ',nofiles,' files, totalling ',nobytes,' bytes.');
end.
