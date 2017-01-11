{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S+,V-}
{$M 1024,0,655360}

program site_generator;

uses dos,crt;

const

 COM1        = 1;
 COM2        = 2;
 COM3        = 3;
 COM4        = 4;

 NO_PAR      = 0;             { parity settings }
 EV_PAR      = 1;
 OD_PAR      = 2;

{$I lastrev.inc}

{$I crc16.inc}

{$I apdefs.inc}

procedure correct(var s:sitecode);

var
 loop:byte;

begin
 while length(s)<4 do s:='0'+s;
 for loop:=1 to 4 do s[loop]:=upcase(s[loop]);
 s[0]:=#4;
end;

var
 apnsfile:file of config;
 site:sitecode;
 checksum:byte;
 crc,loop:word;
 ioerror:integer;
 ac:string;

begin
 crc:=0;
 writeln;
 writeln('SiteGen v'+version+' ('+lastrev+'), Copyright (c) 1991 Michael E. Ralphson');
 writeln;
 write('AC: ');
 textattr:=0;
 readln(ac);
 textattr:=7;
 writeln;
 if ac<>'jodrell bank' then exit;
 write('Site Identification: ');
 readln(site);
 if site='' then exit;
 correct(site);
 setup.site:=site;
 for loop:=1 to sizeof(checkconf)-2 do
  crc16(checksum,crc,security[loop]);
 setup.crc:=crc;
 assign(apnsfile,'APNS.CFG');
 rewrite(apnsfile);
 write(apnsfile,setup);
 close(apnsfile);
 ioerror:=ioresult;
 if ioerror<>0 then writeln(#7'IO error ',ioerror,' while writing APNS.CFG');
end.
