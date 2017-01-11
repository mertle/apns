{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 4096,0,0}
program prntest;

uses crt,dos;

type
 scrpair=record
  chara:char;
  attr:byte;
 end;
 screentype=array [1..25,1..80] of scrpair;
 langtype=(english,french,spanish);

const
 prnresult:boolean=false;
 test:boolean=false;

var
 r:registers;
 c:char;
 screen:screentype;
 monoscreen:screentype absolute $B000:0000;
 colourscreen:screentype absolute $B800:0000;
 debugline,s:string;
 language:langtype;
 status:array [1..5] of string[25];

procedure centre(s:string);

begin
 gotoxy(succ(((succ(lo(windmax)-lo(windmin)))-length(s)) div 2),wherey);
 write(s);
end;

procedure debug(display:boolean);

var
 s:string;

begin
 if r.ah and 128=128 then s:=status[1] else s:=status[2];
 s:=s+', ';
 if r.ah and 32=32 then s:=s+status[3]+', ';
 if r.ah and 8=8 then s:=s+status[4]+', ';
 if r.ah and 1=1 then s:=s+status[5]+', ';
 if r.ah and 64=64 then s:=s+'ALS, ';
 if r.ah and 16=16 then s:=s+'PSLS, ';
 if r.ah and 2=2 then s:=s+'Bit 2, ';
 if r.ah and 4=4 then s:=s+'Bit 4';
 if display then begin
  gotoxy(1,3);
  clreol;
  centre(s);
  clreol;
 end;
 debugline:=s;
end;

function error:boolean;

begin
 error:=((r.ah and 64<>64) and (r.ah and 16<>16)) or ((r.ah and 8=8) or (r.ah and 32=32)) or (test);
end;

procedure finish(b:byte);

var
 o:text;

begin
 if prnresult then begin
  assign(o,'PRNTEST.GE2');
  rewrite(o);
  writeln(o,debugline);
  close(o);
  if ioresult<>0 then write(#7);
 end;
 halt(b);
end;

procedure help;

begin
 writeln;
 writeln('PrnTest switches, eg: PRNTEST 2FR (LPT2, French, Report)');
 writeln;
 writeln(' 1 use LPT1 (PRN)');
 writeln(' 2 use LPT2');
 writeln(' E use English messages');
 writeln(' F use French messages');
 writeln(' S use Spanish messages');
 writeln(' R write PRNTEST.GE2 text file');
 writeln(' C force CGA / EGA / VGA operation');
 writeln(' M force MDA / Hercules operation');
 writeln(' T test mode, always report an error');
 writeln(' ? display this summary');
 halt(0);
end;

var
 count:longint;
 mode:integer;
 prno,loop,ox,oy,oc:byte;

begin
 language:=english;
 prno:=0; {LPT1 aka PRN}
 mode:=lastmode;
 if paramcount>0 then s:=paramstr(1) else s:='';
 for loop:=1 to length(s) do s[loop]:=upcase(s[loop]);
 if pos('2',s)>0 then prno:=1; {LPT2}
 if pos('T',s)>0 then test:=true;
 if pos('F',s)>0 then language:=french;
 if pos('S',s)>0 then language:=spanish;
 if pos('M',s)>0 then mode:=mono;
 if pos('C',s)>0 then mode:=co80;
 if pos('R',s)>0 then prnresult:=true;
 if pos('?',s)>0 then help;
 ox:=wherex;
 oy:=wherey;
 oc:=textattr;

 if mode=mono then begin
  screen:=monoscreen;
  textattr:=112;
 end else begin
  screen:=colourscreen;
  textattr:=62;
 end;
 c:=#0;
 count:=0;
 r.ah:=2;
 r.dx:=prno;
 intr($17,r);
 if error then begin
  gotoxy(14,7);
  write('Ú');
  for loop:=1 to 51 do write('Ä');
  write('¿');
  for loop:=1 to 3 do begin
   gotoxy(14,7+loop);
   write('³');
   gotoxy(66,7+loop);
   write('³');
  end;
  gotoxy(14,11);
  write('À');
  for loop:=1 to 51 do write('Ä');
  write('Ù');
  for loop:=16 to 66 do
   if mode=mono then monoscreen[12,loop].attr:=7
   else colourscreen[12,loop].attr:=8;
  for loop:=8 to 12 do
   if mode=mono then begin
    monoscreen[loop,67].attr:=7;
    monoscreen[loop,68].attr:=7;
   end else begin
    colourscreen[loop,67].attr:=8;
    colourscreen[loop,68].attr:=8;
   end;

  window(15,8,65,10);
  status[1]:='Not busy';
  status[2]:='Busy';
  status[3]:='No Paper';
  status[4]:='Error';
  status[5]:='Time-out';
  clrscr;
  case language of
   french:begin
    centre('L''imprimante n''est pas prˆte, appuyez sur on-line');
    writeln;
    centre('ou pressez ®echap¯ pour terminer.');
    writeln;
    centre('Pressez ®espace¯ pour plus d''information');
    status[1]:='Libre';
    status[2]:='Occup‚';
    status[3]:='Pas de papier';
    status[4]:='Erreur';
    status[5]:='Verifier l''imprimante';
   end;
   spanish:begin
    centre('La impresora esto off-line, por favor');
    writeln;
    centre('corridazo o pulse ®ESCAPE¯ para salir.');
    writeln;
    centre('Pulse la barro espaciadora para mas informac¡¢n.');
    status[1]:='Devocipada';
    status[2]:='Ocupada';
    status[3]:='Falta papel';
    status[4]:='Error';
    status[5]:='Necesita reset';
   end else begin
    centre('The printer is off-line, please correct');
    writeln;
    centre('or press ESCAPE to abort.');
    writeln;
    centre('Press SPACE for more information');
   end;
  end;
  repeat
   delay(100);
   r.ah:=2;
   r.dx:=prno;
   intr($17,r);
   inc(count);
   if keypressed then c:=readkey;
   if c=' ' then debug(true);
  until (not error) or (c=#27) or (count=450);
  if mode=mono then monoscreen:=screen else colourscreen:=screen;
 end;
 window(1,1,80,25);
 gotoxy(ox,oy);
 textattr:=oc;
 debug(false);
 if (c=#27) or (count=450) then begin
  debugline:='N '+debugline;
  finish(1);
 end else begin
  debugline:='Y '+debugline;
  finish(0);
 end;
end.
