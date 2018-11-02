{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,655360}

program ap_code;

uses dos,crt,utility,random6;

type
 comport=record
  base:word;
  irq,int:byte;
 end;

{$I lastrev.inc}
{$I apcrc.inc}
{$I apdefs.inc}

{**************************************************************************}

const
 data1:string[36]='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
 data2:string[36]='"-$(:^\+|= #O@<&._%,;!*>7[g/)?~]J{a}';

function encode(v:string):longint;

var
 s:string;
 l:longint;
 loop:byte;

begin
 s:=v;
 for loop:=1 to 4 do s[loop]:=data2[pos(s[loop],data1)];
 move(s[1],l,4);
 encode:=l;
end;

{**************************************************************************}

procedure encrconf;

var
 loop:word;

begin
 randseed:=18572;
 for loop:=1 to sizeof(config) do security[loop]:=security[loop] xor random(256);
end;

{**************************************************************************}

procedure correct(var s:sitecode);

var
 loop:byte;

begin
 while length(s)<4 do s:='0'+s;
 for loop:=1 to 4 do s[loop]:=upcase(s[loop]);
 s[0]:=#4;
end;

{*************************************************************************}

var
 apnsfile:file of config;
 f:text;
 site:sitecode;
 crc,loop,inner:word;
 ioerror:integer;
 ac,fname,temp:string;
 c:char;

begin
 if paramcount>0 then clrscr;
 crc:=18572;
 writeln;
 writeln('ApCode v'+version+' ('+lastrev+'), Copyright (c) 1993 Michael E. Ralphson');
 writeln;
 write('Authorisation Code (if in doubt see Mike Ralphson): ');
 textattr:=0;
 if paramcount=0 then readln(ac) else begin
  ac:=paramstr(1);
  writeln;
 end;
 textattr:=7;
 writeln;
 ac:=ac+'Œ‡';
 crc16(crc,ac[1],length(ac));
 write('Site Identification: ');
 if paramcount<2 then readln(site) else begin
  site:=paramstr(2);
  writeln(site);
 end;
 if site='' then exit;
 correct(site);
 setup.site:=site;
 crc16(crc,security,sizeof(security));
 setup.crc:=crc;
 writeln;
 write('Limited copy (y/N) : ');
 if paramcount<3 then c:=readkey else begin
  temp:=paramstr(3);
  c:=temp[1];
 end;
 c:=upcase(c);
 if c<>'Y' then c:='N';
 writeln(c);
 if c='Y' then setup.crc:=not setup.crc;
 encrconf;
 if paramcount=0 then fname:='APNS.CFG' else fname:='APNS'+site+'.CFG';
 assign(apnsfile,fname);
 rewrite(apnsfile);
 write(apnsfile,setup);
 close(apnsfile);
 ioerror:=ioresult;
 if ioerror<>0 then writeln(#7'IO error ',ioerror,' while writing ',fname);
 if paramcount>0 then begin
  fname:='APNS.REG';
  assign(f,fname);
  if exist(fname) then append(f) else rewrite(f);
  ioerror:=ioresult;
  if ioerror<>0 then begin
   writeln(#7'IO error ',ioerror,' while writing APNS.REG');
   exit;
  end;
  writeln(f,'APNS License: ',site,' - Serial Number: ',site,encode(site));
  close(f);
 end;
end.
