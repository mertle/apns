{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}

program APNS;

{DEFINE debug}

uses
 crt,dos,comms;

{$I lastrev.inc}

{$I english.inc}

{$I crc16.inc}

{$I apdefs.inc}

type
 screen=array [1..3840] of byte;

var
 crc:word;
 checksum:byte;
 exitsave:pointer;               {points to termination routine}

 thatsallfolks:boolean;          {time for bed?}

 setupfile:file of config;       {disk file for setup}
 cfgname:string[128];

 cursor:boolean;                 {holds current cursor state}
 lights:boolean;
 sending:boolean;

 c:char;
 reg:registers;                  {global variables}
 s,laststr:string;
 thruput:string[7];
 statusline,time,date,timer:string[80];
 lenlaststr:byte absolute laststr;
 hour,min,sec:word;
 loop:word;
 ocd:boolean;
 oldcolour:byte;
 mode:byte;
 homepath,                       {where .EXT .PRO .CAP files are}
 curpath,                        {directory for upload download etc}
 oldpath,
 curfile:string[128];
 curname:string[8];
 curport:string[1];
 curspeed:string[5];             {global %parameters}

 dir:dirstr;
 name:namestr;                   {fsplit of invoked name}
 ext:extstr;

 cursor_spec:word;

 oldx,oldy:byte;                 {window stuff}
 wmin,wmax:word;

 cfgfile:file of config;
 logfile:text;
 ioerror:integer;
 ccloaded:boolean;

{**************************************************************************}

procedure beep;

begin
 if setup.sound then write(#7);
end;

{**************************************************************************}

function stringof(c:char;l:byte):string;

var
 s:string;

begin
 s[0]:=chr(l);
 fillchar(s[1],l,c);
 stringof:=s;
end;

{**************************************************************************}

procedure cursoroff;

begin
 asm
  mov ah,1
  mov cx,$2020
  int $10
 end;
 cursor:=false;
end;

{**************************************************************************}

procedure cursoron;

begin
 asm
  mov ah,1
  mov cx,cursor_spec
  int $10
 end;
 cursor:=true;
end;

{**************************************************************************}

procedure centre(s:string);

begin
 gotoxy(((lo(windmax)-lo(windmin))-length(s)+2) shr 1,wherey);
 write(s);
end;

{**************************************************************************}

function exist(s:string):boolean;

var
 f:file;

begin
 assign(f,s);
 reset(f);
 close(f);
 exist:=(ioresult=0);
end;

{**************************************************************************}

function flag(test:boolean;inchar:char):char;

begin
 if test then flag:=upcase(inchar) else flag:=inchar;
end;

{**************************************************************************}

function getstatus:string;

const
 parities:array[no_par..od_par] of char=('N','E','O');
 startsec:shortint=-1;
 startmin:shortint=-1;
 starthour:shortint=-1;
 secon:shortint=0;
 minon:shortint=0;
 houron:shortint=0;

var
 hun,year,month,day,dow:word;
 s1,s2,s3,s4,s5,s6:string[5];
 temp:string[80];

begin
 gettime(hour,min,sec,hun);
 str(hour:2,s1);
 str(min:2,s2);
 str(sec:2,s3);
 if s1[1]=space then s1[1]:='0';
 if s2[1]=space then s2[1]:='0';
 if s3[1]=space then s3[1]:='0';
 time:=s1+':'+s2+':'+s3;
 getdate(year,month,day,dow);
 str(day:2,s1);
 str(month:2,s2);
 str(year:4,s3);
 if s1[1]=space then s1[1]:='0';
 if s2[1]=space then s2[1]:='0';
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
 str(setup.baud:5,s1);
 str(setup.length,s2);
 str(setup.stopbits,s3);
 str(houron:2,s4);
 str(minon:2,s5);
 str(secon:2,s6);
 if s4[1]=space then s4[1]:='0';
 if s5[1]=space then s5[1]:='0';
 if s6[1]=space then s6[1]:='0';
 if carrierdetect then
  timer:='  Elapsed time online '+s4+' hours '+s5+' minutes '+s6+' seconds';
 temp:=' A.P.N.S. Г '+s1+' Г '+s2+'љ'+parities[setup.parity]+'љ'+s3+' Г ';
 if lights then begin
  if carrierdetect then temp:=temp+'CD.' else temp:=temp+'cd.';
  if charwaiting then temp:=temp+'RX.' else temp:=temp+'rx.';
  if sending then temp:=temp+'TX.' else temp:=temp+'tx.';
  if port[portbase+MSR] and CTS=CTS then temp:=temp+'CTS.' else
   temp:=temp+'cts.';
  if port[portbase+MCR] and RTS=RTS then temp:=temp+'RTS.' else
   temp:=temp+'rts.';
 end else temp:=temp+
  flag(carrierdetect,'o')+'љ'+
  flag(direct,'d')+'љcљpљeљaљ'+
  flag(setup.sound,'s')+'љ'+
  flag(not setup.direct,'b')+'љ'+
  flag(setup.snow,'w');
 temp:=temp+' Г '+s4+':'+s5+':'+s6+' Г '+time+' '+date+space;
 getstatus:=temp;
end;

{**************************************************************************}

procedure status;

var
 a:byte;
 sl:string[80];
 wmin,wmax:word;
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

procedure log(var f:text;s:string);

begin
 writeln(s);
 writeln(f,s);
 status;
end;

{**************************************************************************}

{$F+}procedure exitroutine;{$F-}

var
 x,y:byte;

begin
 closecomms;
 if ccloaded then begin
  reg.ax:=$D001;
  intr($2F,reg);
 end;
 x:=wherex;
 y:=wherey;
 window(1,1,80,25);
 gotoxy(1,25);
 clreol;
 textattr:=7;
 cursoron;
 gotoxy(x,y);
 if erroraddr<>nil then begin
  str(exitcode,s);
  log(logfile,'! Abnormal program termination. Please report error '+s);
  writeln;
 end;
 writeln(logfile);
 writeln(logfile,'  APNS exited at '+time+' on the '+date);
 close(logfile);
 exitproc:=exitsave;
end;

{**************************************************************************}

procedure anykey(outer:byte;short:boolean);

var
 inner:word;
 c:char;
 s:string[2];
 old:byte;

begin
 cursoroff;
 old:=textattr;
 textcolor(setup.bclr);
 textbackground(setup.fclr);
 writeln;
 repeat
  str(outer:2,s);
  if s[1]=' ' then s[1]:='0';
  if short then centre('Press any key ('+s+')') else
  centre('Press any key to continue (or wait '+s+' seconds)');
  inner:=0;
  repeat
   delay(1);
   inc(inner);
  until (inner=1000) or keypressed;
  dec(outer);
 until (outer=0) or keypressed;
 while keypressed do c:=readkey;
 textattr:=7;
 if wherey=25 then clreol;
 textattr:=old;
 cursoron;
end;

{**************************************************************************}

procedure quiet;

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

procedure replace(var s:string;orig,rep:string;once:boolean);

var
 temp:byte;
 us:string;

begin
 repeat
  us:='';
  for temp:=1 to length(s) do us:=us+upcase(s[temp]);
  temp:=pos(orig,us);
  if temp>0 then begin
   delete(s,temp,length(orig));
   insert(rep,s,temp);
  end;
 until (temp=0) or once;
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
 via,oldcap:boolean;
 tail,old,oldt:string[128];
 temp:byte;
 search:string[128];

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
  writeln(lf+'Loading secondary command processor.'+lf);
  tail:='/C '+old+space+tail;
  if old+oldt='' then tail:='';
  command:=getenv('COMSPEC');
 end else writeln(lf+'Running external program.'+lf);
 writeln('Command line: '+command+space+tail+lf);
 exec(command,tail);
 reg.ah:=$0F;
 intr($10,reg);
 if reg.al<>mode then begin
  reg.ax:=mode;
  intr($10,reg);
 end;
end;

{**************************************************************************}

procedure initialise;

begin
 writeln;
 with setup do setport(comport,baud,parity,length,stopbits);
 opencomms;
 if setup.cmdinit<>'' then begin
  sending:=true;
  status;
  auxwrite(setup.cmdinit);
  sending:=false;
  status;
  delay(20);
  while charwaiting do begin
   status;
   write(chr(getaux));
   delay(20);
  end;
 end;
 writeln;
end;

{**************************************************************************}

procedure copyright;

begin
 writeln(
  cr+lf+' млллм      лллллллм   лл    лл     мллллллм'
 +cr+lf+'лллпллл     лл    лл   ллл   лл     ллп  плл                 The'
 +cr+lf+'лл   лл     лл    лл   лллл  лл     ллм         Aurora Polling Network System'
 +cr+lf+'лл   лл     лллллллп   ллпллмлл      пллллм');
writeln('ллллллл     лл         лл  лллл          плл        Designed and Coded by'
 +cr+lf+'лл   лл     лл         лл   ллл     ллм  млл         Michael E. Ralphson'
 +cr+lf+'лл   лл  м  лл      м  лл    лл  м  пллллллп  м');
writeln(
  cr+lf+'Version '+version+' (Last Revision '+lastrev+')',
  cr+lf+'Copyright (c) 1990-1991 Michael E. Ralphson, All Rights Reserved');
end;

{**************************************************************************}

procedure hangup(ask:boolean);

var
 b:byte;

begin
 status;
 writeln('Hanging up...');
 lowerdtr;
 delay(500);
 raisedtr;
 if carrierdetect then auxwrite(setup.cmdhangup)
  else sendaux(13);
 delay(100);
 while charwaiting do begin
  b:=getaux;
  delay(10);
 end;
 delay(250);
 writeln;
 if carrierdetect and not direct then log(logfile,'* Hangup failed');
end;

{**************************************************************************}

{$I dial.inc}

{**************************************************************************}

{ APNS }

begin
 mode:=lastmode;
 if not(mode in [BW80,CO80,MONO]) then begin
  mode:=CO80;
  textmode(CO80);
 end;

 asm
  mov ah,3
  mov bh,3
  int $10
  mov cursor_spec,cx
 end;

 lights:=true;
 curfile:='';
 s:=fexpand(paramstr(0));
 fsplit(s,dir,name,ext);
 homepath:=dir;
 curname:=name;
 s:=homepath+'APNS.LOG';
 assign(logfile,s);
 if exist(s) then append(logfile) else rewrite(logfile);
 cfgname:=homepath+'APNS.CFG';
 writeln('Retrieving configuration...');
 assign(setupfile,cfgname);
 reset(setupfile);
 read(setupfile,setup);
 close(setupfile);

 ioerror:=ioresult;
 if ioerror<>0 then begin
  writeln('Error ',ioerror,' reading configuration file');
  exit;
 end;

 crc:=0;
 for loop:=1 to sizeof(config)-2 do crc16(checksum,crc,security[loop]);
 if crc<>setup.crc then begin
  writeln('Configuration file has been tampered with');
  exit;
 end;

 getdir(0,curpath);

 exitsave:=exitproc;
 exitproc:=@exitroutine;

 {This is the first place the variable SETUP is referenced}

 directvideo:=setup.direct;
 checksnow:=setup.snow;
 statusline:='';
 direct:=setup.nulmodem;

 if mode<>CO80 then begin
  setup.fclr:=7;
  setup.bclr:=0;     {Define monochrome colour scheme}
  setup.wfclr:=0;
  setup.wbclr:=7;
  setup.hfclr:=7;
  setup.hbclr:=0;
 end;
 textcolor(setup.fclr);
 textbackground(setup.bclr);
 clrscr;
 window(1,1,80,24);

 copyright;
 writeln;
 anykey(9,false);
 clrscr;
 thatsallfolks:=false;
 laststr:='';
 cursor:=true;
 str(setup.baud:5,curspeed);
 str(setup.comport,curport);
 ocd:=false;
 status;

 writeln(logfile);
 writeln(logfile,stringof('Э',79));
 writeln(logfile);
 writeln(logfile,'  APNS started at '+time+' on the '+date);

 initialise;

 reg.ah:=$D0;
 reg.al:=0;
 reg.cx:=0;
 intr($2F,reg);

 ccloaded:=(reg.al>0) and (reg.bx=$4343);

 if ccloaded then begin
  log(logfile,'! Carbon Copy loaded - disabling');
  reg.ax:=$D002;
  intr($2F,reg);
 end;

 if paramcount>0 then s:=paramstr(1) else s:='DIAL';
 for loop:=1 to length(s) do s[loop]:=upcase(s[loop]);
 if s='DIAL' then begin
  log(logfile,'  Dialling mode');
  dial;
 end else begin
  log(logfile,'  Waiting for call');
  wait;
 end;

end. {APNS}
