{$A+,B-,D-,E-,F-,G+,I-,L-,N-,O-,P-,Q-,R-,S-,T-,V-,X+,Y-}
{$M 16384,0,0}

program APNS;

{DEFINE debug}

uses
 test186,crt,dos,comms,utility,random6;

const
 md=50;

{$I lastrev.inc}
{$I apcrc.inc}
{$I apdefs.inc}
{$I runerr.inc}
{$I unixtime.inc}

type
 bufty=array [0..61439] of byte;
 bufptr=^bufty;

var 
 buf:bufptr;
 bufpos,buflen,bufseg:word;
 exitsave:pointer;               {points to termination routine}
 save:screen;
 s,laststr:string;
 crc,sitecrc,loop,parm,wmin,wmax,hour,min,sec:word;
 ioerror:integer;
 curport:string[1];
 thruput:string[9];

 setupfile:file of config;       {disk file for setup}
 cfgfile:file of config;
 logfile:text;

 homepath,                       {where .EXT .PRO .CAP files are}
 curpath,                        {directory for upload download etc}
 oldpath,
 curfile,
 cfgname:string[128];

 r:registers;                    {global variables}

 job:string[12];
 thatsallfolks:boolean;          {time for bed?}
 fifotested:boolean;             {FIFO already tested?}
 lights:boolean;
 sending:boolean;
 killdata:boolean;
 currwindow,currsession:byte;
 c:char;
 statusline,time,date,timer:string[80];
 lenlaststr:byte absolute laststr;
 ocd:boolean;
 oldcolour,logwin,phour:byte;
 curspeed:string[6];             {global %parameters}

 dir:dirstr;
 name:namestr;                   {fsplit of invoked name}
 ext:extstr;

 oldx,oldy:byte;                 {window stuff}

 ccloaded,pcloaded,boo,exitafter:boolean;
 poller:string[4];

{**************************************************************************}

procedure encrconf;

var
 loop:word;

begin
 randseed:=18572;
 for loop:=1 to sizeof(config) do security[loop]:=security[loop] xor random(256);
end;

{**************************************************************************}

procedure win(b:byte);

begin
 if (b<>currwindow) and (currwindow<>$FF) then begin
  case b of
   1:window(4,2,77,2);
   2:begin
      window(5,5,76,12);
      gotoxy(1,8);
     end; 
   3:begin
      window(5,15,76,22);
      gotoxy(1,8);
     end;
  end;
  currwindow:=b;
 end; 
end;

{**************************************************************************}

function getstatus:string;

const
 startsec:shortint=-1;
 startmin:shortint=-1;
 starthour:shortint=-1;
 secon:shortint=0;
 minon:shortint=0;
 houron:shortint=0;

var
 hun,year,month,day,dow:word;
 s1,s2,s3:string[4];
 elapse:string[8];
 temp:string[80];

begin
 gettime(hour,min,sec,hun);
 s1:=itos(hour,2);
 s2:=itos(min,2);
 s3:=itos(sec,2);
 time:=s1+':'+s2+':'+s3;
 getdate(year,month,day,dow);
 s1:=itos(day,2);
 s2:=itos(month,2);
 str(year:4,s3);
 date:=s1+'/'+s2+'/'+s3;
 if carrierdetect then begin
  if startsec<0 then begin
   startsec:=sec;
   startmin:=min;
   starthour:=hour;
  end;
  secon:=sec-startsec;
  minon:=min-startmin;
  houron:=hour-starthour;
  if secon<0 then begin
   inc(secon,60);
   dec(minon);
  end;
  if minon<0 then begin
   inc(minon,60);
   dec(houron);
  end;
  if houron<0 then inc(houron,24);
 end else begin
  startsec:=-1;
  secon:=0;
  minon:=0;
  houron:=0;
 end;
 s1:=itos(houron,2);
 s2:=itos(minon,2);
 s3:=itos(secon,2);
 elapse:=s1+':'+s2+':'+s3;
 if carrierdetect then
  timer:='  Elapsed time '+elapse;
 temp:=' '+job+' ³ '+curspeed+' ³ '+curport+' ³ ';
 if carrierdetect then temp:=temp+'CD.' else temp:=temp+'cd.';
 if charwaiting then temp:=temp+'RX.' else temp:=temp+'rx.';
 if sending then temp:=temp+'TX.' else temp:=temp+'tx.';
 if port[portbase+MSR] and CTS=CTS then temp:=temp+'CTS.' else
  temp:=temp+'cts.';
 if port[portbase+MCR] and RTS=RTS then temp:=temp+'RTS' else
  temp:=temp+'rts';
 temp:=temp+' ³ '+elapse+' ³ '+time+' '+date+space;
 getstatus:=temp;
end;

{**************************************************************************}

procedure status;

var
 wmin,wmax:word;
 a:byte;
 sl:string[80];
 oc:boolean;
 ox,oy:byte;

begin
 ioerror:=ioresult;
 sl:=getstatus;
 if sl<>statusline then begin
  oc:=cursor;
  wmin:=windmin;
  wmax:=windmax;
  statusline:=sl;
  ox:=wherex;
  oy:=wherey;
  cursoroff;
  window(1,1,80,25);
  a:=textattr;
  textattr:=112;
  gotoxy(1,25);
  centre(statusline);
  clreol;
  textattr:=a;
  windmin:=wmin;
  windmax:=wmax;
  gotoxy(ox,oy);
  if oc then cursoron;
 end;
end;

{**************************************************************************}

procedure log(s:string);

var
 temp:string;

begin
 temp:=getstatus;
 writeln(logfile,time+' '+s);
 flush(logfile);
 if running then win(2);
 delete(s,1,2);
 writeln(s);
end;

{**************************************************************************}

procedure qlog(s:string);

var
 temp:string;

begin
 temp:=getstatus;
 writeln(logfile,time+' '+s);
 flush(logfile);
end;

{**************************************************************************}

procedure exitroutine; far;

begin
 exitproc:=exitsave;
 if running then closecomms;
 encrconf;
 if ccloaded then begin
  r.ax:=$D001;
  intr($2F,r);
 end;
 if erroraddr<>nil then begin
  log('! Abnormal program termination. Please report the following:');
  log('! '+runerror(exitcode));
  erroraddr:=nil;
  writeln;
 end else qlog('- APNS exited ('+date+')');
 close(logfile);
 textattr:=7;
 window(1,1,80,25);
 gotoxy(1,25);
 clreol;
 cursoron;
 gotoxy(1,24);
end;

{**************************************************************************}

procedure errcheck(s:string);

begin
 ioerror:=ioresult;
 if ioerror<>0 then begin
  log('! '+runerror(ioerror)+s);
  halt;
 end;
end;

{**************************************************************************}

procedure anykey(outer:byte;short:boolean);

var
 inner:word;
 s:string[2];
 old:byte;

begin
 cursoroff;
 old:=textattr;
 textcolor(colset.bclr);
 textbackground(colset.fclr);
 writeln;
 repeat
  s:=itos(outer,2);
  if short then centre('Press any key ('+s+')') else
  centre('Press any key to continue (or wait '+s+' seconds)');
  inner:=0;
  repeat
   delay(10);
   inc(inner);
  until (inner=100) or keypressed;
  dec(outer);
 until (outer=0) or keypressed;
 while keypressed do readkey;
 textattr:=7;
 if wherey=25 then clreol;
 textattr:=old;
 cursoron;
end;

{**************************************************************************}

procedure drawbox;

var
 loop:byte;

begin
 window(1,1,80,25);
 write('ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»');
 write('º                                                                              º');
 write('ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶');
 write('º ÕÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ APNS Status ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¸ º'); for loop:=1 to 8 do
 write('º ³                                                                          ³ º');
 write('º ÔÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¾ º');
 write('º ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ Modem Communications ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ· º'); for loop:=1 to 8 do
 write('º º                                                                          º º');
 write('º ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½ º');
 write('ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼');
 win(1);
 centre('APNS Version '+version+' Copyright (c) 1993 Michael E. Ralphson');
end;

{**************************************************************************}

procedure quietall;

var
 c:char;

begin
 status;
 c:=upcase(chr(getaux));
 if lenlaststr=255 then delete(laststr,1,1);
 laststr:=laststr+c;
end;

{**************************************************************************}

procedure quietasc;

var
 c:char;

begin
 status;
 c:=upcase(chr(getaux));
 if c in [' ','A'..'Z'] then begin
  if lenlaststr=255 then delete(laststr,1,1);
  laststr:=laststr+c;
 end;
end;

{**************************************************************************}

procedure pathsearch(match:string;var s:string;var ext:extstr);

var
 search:string;

begin
 if not(exist(match)) then begin
  search:=fsearch(match,getenv('PATH'));
  if search<>'' then begin
   s:=fexpand(search);
   ext:='.EXE';
  end;
 end;
end;

{**************************************************************************}

procedure run(command:string);

var
 tail,old,oldt,search:string[127];
 via,oldcap:boolean;
 temp:byte;

begin
 temp:=pos(space,command);
 if temp>0 then begin
  tail:=copy(command,succ(temp),length(command)-temp);
  delete(command,temp,succ(length(command)-temp));
 end else tail:='';
 old:=command;
 oldt:=tail;

 replace(tail,'%PATH',curpath,false);
 replace(tail,'%PORT',curport,false);
 replace(tail,'%SPEED',curspeed,false);

 via:=false;
 command:=fexpand(command);
 fsplit(command,dir,name,ext);
 if ext='' then if exist(old+'.COM') then begin
  ext:='.COM';
  command:=command+ext;
 end else if exist(old+'.EXE') then begin
  ext:='.EXE';
  command:=command+ext;
 end;
 pathsearch(command,command,ext);
 if not(exist(command)) then pathsearch(name+'.EXE',command,ext);
 if not(exist(command)) then pathsearch(name+'.COM',command,ext);

 if (ext<>'.EXE') and (ext<>'.COM') then via:=true;
 if not via then via:=not(exist(command));
 if via then begin
  tail:='/C '+old+space+tail;
  if old+oldt='' then tail:='';
  command:=getenv('COMSPEC');
 end;
 
 s:='Executing: '+command+space+tail;
 if length(s)>70 then s[0]:=#70;
 qlog('  '+s);
 win(2);
 writeln(s);
 save:=dosptr^;
 textattr:=7;
 window(1,1,80,25);
 clrscr;
 writeln(s+lf);

 cursoron;
 exec(command,tail);
 r.ah:=$0F;
 intr($10,r);
 if r.al<>scrmode then begin
  r.ax:=scrmode;
  intr($10,r);
 end;
 window(1,1,80,24);
 textcolor(colset.fclr);
 textbackground(colset.bclr);
 cursoroff;
 dosptr^:=save;
 status;
 currwindow:=0;
 win(2);
end;

{**************************************************************************}

function init(var s:string):boolean;

var
 chs:word;
 loop:byte;
 result:boolean;
 response:byte;

begin
 job:='Init. Modem ';
 status;
 win(3);
 sending:=true;
 chs:=0;
 while charwaiting do response:=getaux;
 for loop:=1 to length(s) do begin
  auxwrite(s[loop]);
  delay(md);
  while charwaiting do begin
   status;
   write(chr(getaux));
   inc(chs);
  end;
 end;
 sending:=false;
 status;
 repeat
  response:=auxtb(1000);
  if not timedout then begin
   write(chr(response));
   inc(chs);
  end; 
 until timedout; 
 result:=(chs>0) or (s='');
 if not result then log('! Modem initialisation failed');
 init:=result;
end;

{**************************************************************************}

function initialise(var s:string):boolean;

var
 loop:byte;
 test:boolean;

begin
 win(2);
 write('Initialising modem, ',setup.modemname);
 with setup do setport(comport,baud,parity,length,stopbits);
 if not running then opencomms;
 if setup.usefifos then test:=setfifo else test:=false;
 if test and (not fifotested) then begin
  writeln(' (FIFO)');
  repeat
   loop:=auxtb(1000);
  until timedout;
 end else writeln;
 fifotested:=true;
 initialise:=init(s);
end;

{**************************************************************************}

procedure copyright;

begin
 writeln;
 centre('ÚÄÄÄÄÄÄ· ÚÄÄÄÄÄ· ÚÄÄÄÄ·ÚÄ· ÚÄÄÄÄÄ·');   writeln;
 centre('³ ÖÄÄ¿ º ³ ÖÄ¿ º ³ Ö¿ º³ º ³ ÖÄÄÄ½');   writeln;
 centre('³ ÓÄÄÙ º ³ ÓÄÙ º ³ º³ º³ º ³ ÓÄÄÄ·');   writeln;
 centre('³ ÖÄÄ¿ º ³ ÖÄÄÄ½ ³ º³ º³ º ÀÄÄÄ¿ º');   writeln;
 centre('³ º  ³ º ³ º     ³ º³ ÓÙ º ÚÄÄÄÙ º');   writeln;
 centre('ÀÄ½  ÀÄ½ ÀÄ½     ÀÄ½ÀÄÄÄÄ½ ÀÄÄÄÄÄ½');   writeln;
 writeln;
 centre('The Automated Polling Network System'); writeln;
 writeln;
 centre('Release Version '+version); writeln;
 writeln;
 centre('Designed and Coded by Michael E. Ralphson'); writeln;
 writeln;
 centre('Copyright (c) 1990 - 1993 Michael E. Ralphson, All Rights Reserved');
end;

{**************************************************************************}

procedure receive;

var
 c:char;

begin
 job:='Receiving   ';
 status;
 win(3);
 c:=upcase(chr(getaux));
 write(c);
 if c>#31 then begin
  laststr:=laststr+c;
  if length(laststr)=255 then delete(laststr,1,1);
 end; 
end;

{**************************************************************************}

procedure hangup;

var
 b:byte;

begin
 job:='Hanging Up  ';
 status;
 win(2);
 repeat
  delay(500);
  status;
  lowerdtr;
  delay(500);
  raisedtr;
  delay(500);
  laststr:='';
  if carrierdetect then auxwrite(setup.cmdhangup)
   else auxwrite(setup.cmdinit);
  delay(500);
  while charwaiting do quietall;
 until ((pos('OK',laststr)<>0) and not carrierdetect) or (keypressed);
 delay(1000);
 if (carrierdetect) and (not nulmodem) then log('* Hangup failed');
end;

{**************************************************************************}

function escpressed:boolean;

var
 c:char;

begin
 escpressed:=false;
 if keypressed then begin
  c:=readkey;
  if c=#27 then escpressed:=true;
 end; 
 if not carrierdetect then escpressed:=true;
 if abort then escpressed:=true;
end;

{*************************************************************************}

procedure allocbuf;

var
 size,temp:word;

begin
 size:=mem_avail;
 if size>3840 then size:=3840;
 buflen:=size*16;
 bufpos:=0;
 bufseg:=mem_alloc(size);
 buf:=ptr(bufseg,0);
end;

{**************************************************************************}

{$I route.inc}
{$I dial.inc}
{$I terminal.inc}

{**************************************************************************}

{ APNS }

begin

 exitsave:=exitproc;
 exitproc:=@exitroutine;

 checkbreak:=false;

 s:=getstatus;

 writeln('APNS v',version);

 fifotested:=false;
 currwindow:=0;
 currsession:=0;
 job:='Starting Up ';
 lights:=true;
 curfile:='';

 s:=fexpand(paramstr(0));
 fsplit(s,dir,name,ext);
 homepath:=dir;

 s:=homepath+'APNS.LOG';
 assign(logfile,s);
 if exist(s) then append(logfile) else rewrite(logfile);
 errcheck(' while opening log file');
 writeln(logfile);
 qlog('- APNS started ('+date+')');

 cfgname:=homepath+'APNS.CFG';

 assign(setupfile,cfgname);
 reset(setupfile);
 errcheck(' while reading configuration file');
 read(setupfile,setup);
 close(setupfile);
 errcheck(' while reading configuration file');

 encrconf;

 crc:=0;
 crc16(crc,security,sizeof(security));
 if crc<>setup.crc then begin
  crc:=not crc;
  killdata:=true;
 end;
 if crc<>setup.crc then begin
  log('! Configuration file has been tampered with');
  exit;
 end;

 getdir(0,curpath);

 {This is the first place the variable SETUP is referenced}

 directvideo:=setup.directvideo;
 checksnow:=setup.snow;
 statusline:='';
 nulmodem:=setup.nulmodem;

 if scrmode=CO80 then move(setup.fclr,colset,7) else move(monset,colset,7);
 textcolor(colset.fclr);
 textbackground(colset.bclr);
 clrscr;
 window(1,1,80,24);

 copyright;
 writeln;
 anykey(9,false);
 clrscr;
 cursoroff;
 drawbox;
 thatsallfolks:=false;
 laststr:='';
 timer:='No DCD asserted';
 cursor:=false;
 str(setup.baud:6,curspeed);
 str(setup.comport,curport);
 ocd:=false;
 comdata[5]:=setup.com5;

 status;
 win(2);

 r.ax:=$D000;
 r.cx:=0;
 intr($2F,r);
 ccloaded:=(r.al>0) and (r.bx=$4343);

 if ccloaded then begin
  log('! Carbon Copy loaded - disabling');
  r.ax:=$D002;
  intr($2F,r);
 end;

 r.ax:=$2B44;
 r.bx:=$4D41;
 r.cx:=$7063;
 r.dx:=$4157;
 intr($21,r);
 pcloaded:=(r.ax=$4F4B) or (r.ax=$6F6B);

 if pcloaded then log('! PcAnywhere loaded');

 sitecrc:=0;
 crc16(sitecrc,setup.site,5);
 if sitecrc=6541 then log('! This is a demonstration version only');
 if killdata     then log('! This is a limited demo version only');

 route;

 s:='';
 boo:=initialise(s);
 exitafter:=setup.exitafter;

 if paramcount=0 then dial else
 for parm:=1 to paramcount do begin
  exitafter:=setup.exitafter;
  s:=paramstr(parm);
  s:=ucase(s);
  if (length(s)>4) and (copy(s,1,4)='DIAL') then begin
   delete(s,1,4);
   val(s,currsession,ioerror);
   if currsession>0 then dec(currsession);
   s:='DIAL';
  end;
  if s='WAITONCE' then begin
   exitafter:=true;
   s:='WAIT';
  end;
  if (length(s)=6) and (copy(s,1,2)='WW') then begin
   val(copy(s,3,2),phour,ioerror);
   if phour<24 then setup.waitstart:=phour;
   val(copy(s,5,2),phour,ioerror);
   if phour<24 then setup.waitfinish:=phour;
  end else
  if (length(s)=6) and (copy(s,1,2)='DW') then begin
   val(copy(s,3,2),phour,ioerror);
   if phour<24 then setup.dialstart:=phour;
   val(copy(s,5,2),phour,ioerror);
   if phour<24 then setup.dialfinish:=phour;
  end else
  if s='TERM' then terminal else
  if s='DIAL' then dial else
  if s='WAIT' then wait else begin
   window(1,1,80,25);
   textattr:=7;
   clrscr;
   if s<>'?' then log('? Unrecognised parameter: '+s);
   writeln(#10'APNS Command-Line Usage Summary');
   writeln(#10'APNS [DIAL] [DIAL#] [WAIT] [WAITONCE] [DWssff] [WWssff] [TERM]');
   writeln(#10'Where # is the Dialling Session Number, ss is the time window start hour and');
   writeln('ff is the time window finish hour.');
   writeln(#10'The default Dialling Session Number is 1, so APNS or APNS DIAL are equivalent');
   writeln('to APNS DIAL1');
   writeln(#10'The WAITONCE command allows immediate use in answering mode.');
   writeln(#10'The DWssff command controls the Dialling Window, and WWssff command controls');
   writeln('the Answer Window.');
   writeln(#10'The TERM command starts Terminal Mode');
   halt;
  end;
 end;
end. {APNS}
