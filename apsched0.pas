{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 8192,0,0}

program APSCHED;

uses
 crt,dos,utility,random6,gesec;

type
 comport=record
  base:word;
  irq,int:byte;
 end;

{$I lastrev.inc}
{$I apdefs.inc}

const
                           {Ja,Fe,Ma,Ap,Ma,Ju,Ju,Au,Se,Oc,No,De}
 dim:array [1..12] of byte=(31,28,31,30,31,30,31,31,30,31,30,31);
 nod:array [0..6] of string[6]=('Sun','Mon','Tues','Wednes','Thurs','Fri','Satur');
 pass:string[20]='DOS';
 debugstr:string[20]='SOD';

var
 exitsave:pointer;
 s:string;
 logname:string[128];
 time,date,realdate,edate:string[20];
 dow,year,month,day:word;
 apbatch,logfile:text;
 apdat:file of longint;
 next2run:longint;
 ioerror:integer;
 daysofar:word;
 debug:boolean;
 keyboard:byte absolute $40:$17;
 keybtemp:byte;

{**************************************************************************}

procedure encrconf;

var
 loop:word;

begin
 randseed:=18572;
 for loop:=1 to sizeof(config) do security[loop]:=security[loop] xor random(256);
end;

{**************************************************************************}

procedure yesterday;

begin
 dec(dow);
 if dow=65535 then dow:=6; {Sunday to Saturday}
 dec(day);
 if day=0 then begin
  dec(month);
  if month=0 then begin
   month:=12;
   dec(year);
   if year mod 4=0 then dim[2]:=29 else dim[2]:=28;
   day:=dim[month];
  end;
 end;
end;

{**************************************************************************}

procedure maketd;

var
 w1,w2,w3,w4:word;

begin
 gettime(w1,w2,w3,w4);
 getdate(year,month,day,dow);
 realdate:=itos(day,2)+'/'+itos(month,2)+'/'+itos(year mod 100,2);
 if year mod 4=0 then dim[2]:=29; {Leap years}
 if w1<7 then yesterday;
 time:=itos(w1,2)+':'+itos(w2,2)+':'+itos(w3,2);
 date:=itos(day,2)+'/'+itos(month,2)+'/'+itos(year mod 100,2);
end;

{**************************************************************************}

procedure log(s:string);

begin
 maketd;
 s:=time+' '+s;
 writeln(logfile,s);
 if debug then writeln(s);
 flush(logfile);
end;

{**************************************************************************}

procedure exitroutine; far;

var
 x,y:byte;

begin
 exitproc:=exitsave;
 x:=wherex;
 y:=wherey;
 window(1,1,80,25);
 gotoxy(1,25);
 clreol;
 textattr:=7;
 gotoxy(x,y);
 if erroraddr<>nil then begin
  str(exitcode,s);
  log('! Please report '+s);
  writeln;
 end;
 maketd;
 close(logfile);
end;

{**************************************************************************}

function countrycode:byte;

var
 s:string;

begin
 r.ax:=$3800;
 r.ds:=seg(s);
 r.dx:=ofs(s);
 msdos(r);
 countrycode:=r.bx;
end;

{**************************************************************************}

function checkholidays:boolean;

var
 f:text;
 s,hdate:string;
 
begin
 checkholidays:=true;
 s:=homepath+'HOLIDAYS.TXT';
 if exist(s) then begin
  assign(f,s);
  reset(f);
  while not eof(f) do begin
   readln(f,hdate);
   while (hdate<>'') and (hdate[length(hdate)]<=#32) do dec(hdate[0]);
   if (hdate=realdate) then checkholidays:=false;
  end;
  close(f);
 end;
end; 

{**************************************************************************}

procedure copyright;

begin
 writeln;
 writeln('APSCHED Version '+version+' (Last Revision '+lastrev+')');
 writeln('Copyright (c) 1991,93 Michael E. Ralphson, All Rights Reserved');
end;

{**************************************************************************}

procedure getsneaky;

var
 s:string;
 loop,inner:byte;
 c:char;

begin
 r.ax:=scrmode;
 intr($10,r);
 writeln;
 s:='';
 loop:=1;
 while keypressed do c:=readkey;
 repeat
  write('Scanning memory for scheduler: ',loop*64:3,'Kb'#13);
  inner:=1;
  repeat
   delay(10);
   inc(inner);
  until keypressed or (inner>100);
  if keypressed then begin
   loop:=1;
   c:=upcase(readkey);
   case c of
    #8:if (s<>'') then delete(s,length(s),1);
    #13:;
    #27:s:='';
    else s:=s+c;
   end;
  end else begin
   inc(loop);
  end;
 until (loop>10) or (pos(pass,s)>0) or (pos(debugstr,s)>0);
 writeln;
 if pos(debugstr,s)>0 then debug:=true;
 if pos(pass,s)>0 then begin
  textattr:=textattr or 128;
  writeln(#13#10'When you are finished in DOS you must REBOOT!');
  textattr:=7;
  if debug then writeln(logfile,'* DOS accessed from ApSched');
  erase(apdat);
  ioerror:=ioresult;
  assign(apbatch,dir+'APSCHED.BAT');
  rewrite(apbatch);
  writeln(apbatch,'@ECHO OFF');
  writeln(apbatch,':START');
  writeln(apbatch,dir[1]+':');
  s:=dir;
  dec(s[0]);
  writeln(apbatch,'CD '+s);
  writeln(apbatch,'APSCHED0.EXE');
  close(apbatch);

  keybtemp:=keyboard;
  keybtemp:=keybtemp and 239;
  inline($FA);
  keyboard:=keybtemp;
  inline($FB);

  writeln;

  halt(0);
 end;
 writeln;
end;

{**************************************************************************}

{ APSCHED }

var
 loop:longint;
 adname,dossite:string;
 c:char;
 event:schedentry;
 schedfile:file of schedentry;
 configfile:file of config;
 doit:boolean;
 week:byte;

begin
 debug:=false;
 textattr:=7;
 clrscr;

 asm
  mov ah,$B
  xor bx,bx
  int $10
 end;

 checkbreak:=false;

 exitsave:=exitproc;
 exitproc:=@exitroutine;

 if debug then copyright;
 
 logname:=homepath+'APNS.LOG';
 assign(logfile,logname);
 if exist(logname) then append(logfile) else rewrite(logfile);

 adname:=homepath+'APSCHED.DAT';

 assign(apdat,adname);
 reset(apdat);
 read(apdat,next2run);
 close(apdat);
 if ioresult<>0 then next2run:=0;

 if debug then writeln(#10'Entering the Schedule file at entry number ',next2run);

 maketd;
 if debug then writeln(logfile,'  APSCHED started ('+date+')');

 daysofar:=0;
 for loop:=1 to pred(month) do inc(daysofar,dim[loop]);
 inc(daysofar,day);
 week:=daysofar div 7;
 if (daysofar/7)>week then inc(week);

 if debug then writeln(#10'Today is ',nod[dow],'day the ',date,' (Day Number ',daysofar,', Week Number ',week,')');

 if keyboard and 16=16 then getsneaky;

 keybtemp:=keyboard;
 keybtemp:=keybtemp and 239;
 inline($FA);
 keyboard:=keybtemp;
 inline($FB);
 
 s:=homepath+'APNS.CFG';
 assign(configfile,s);
 reset(configfile);
 ioerror:=ioresult;
 if ioerror<>0 then begin
  str(ioerror,s);
  log('! Error '+s+' reading config file');
  exit;
 end;
 read(configfile,setup);
 close(configfile);
 encrconf;

 if ge2site<>'' then begin
  dossite:=ucase(getenv('SITE'));
  if (ge2site='TEST') and (dossite='TEST') then setup.site:='TEST';
  if (ge2site<>setup.site) or (dossite<>setup.site) then begin
   writeln;
   writeln('Site Codes do not match.');
   writeln;
   writeln('APNS.CFG Site Code = ',setup.site);
   writeln('SECURITY Site Code = ',ge2site);
   writeln('AUTOEXEC Site Code = ',dossite);
   writeln;
   writeln('Please check that the Security Site Code, APNS Site Code and the SET SITE=');
   writeln('line in AUTOEXEC.BAT all have the same Site Code');
   writeln;
   writeln('Press any key to continue...');
   c:=readkey;
   halt;
  end;
 end;

 s:=homepath+'APNS.SCH';
 assign(schedfile,s);
 reset(schedfile);

 if debug then writeln;
 ioerror:=ioresult;
 if ioerror<>0 then begin
  str(ioerror,s);
  log('! Error '+s+' reading schedule file');
  exit;
 end;

 doit:=false;

 if next2run<filesize(schedfile) then begin
  repeat
   seek(schedfile,next2run);
   read(schedfile,event);
   maketd;
   edate:=event.actdate;

   for loop:=1 to length(edate) do
    if edate[loop]='?' then edate[loop]:=date[loop];

   if (edate='ENDMONTH') and (day=dim[month]) then edate:=date;

   doit:=false;

   {The new decision making process goes here}

   if event.okonday[dow] then doit:=true;

   if debug and (not doit) then log('* Could not run '+event.name+' on this day of the week');

   if event.weekno>0 then
    if event.weekno<>week then begin
     doit:=false;
     if debug then log('* Could not run '+event.name+' on this week number');
    end;

   if edate<>'' then
    if edate<>date then begin
     doit:=false;
     if debug then log('* Could not run '+event.name+' on this date');
    end;

   if (event.lastrun=daysofar) and (event.onceonly) then begin
    doit:=false;
    if debug then log('* '+event.name+' has already been run today');
   end;

   if (event.country in [30..50]) and (event.country<>countrycode) then begin
    doit:=false;
    if debug then log('* '+event.name+' is for another country only');
   end;
   
   if (doit) and (event.holiday) then begin
    doit:=checkholidays;
    if (debug) and (not doit) then log('* '+event.name+' could not be run because it is a holiday');
   end; 

   inc(next2run);
  until (next2run>=filesize(schedfile)) or (doit);
 end;

 if doit then begin
  event.lastrun:=daysofar;
  seek(schedfile,pred(next2run));     {Update lastrun counter for this event}
  write(schedfile,event);             {Write any changes to the schedule file}
 end;

 close(schedfile);
 assign(apbatch,homepath+'APSCHED.BAT');
 rewrite(apbatch);
 writeln(apbatch,'@ECHO OFF');
 writeln(apbatch,':START');
 writeln(apbatch,homepath[1]+':');
 s:=homepath;
 dec(s[0]);
 writeln(apbatch,'CD '+s);
 writeln(apbatch,'APSCHED0.EXE');

 if doit then begin
  assign(apdat,adname);
  rewrite(apdat);
  write(apdat,next2run);
  close(apdat);
  
  {Perform commandline replacements}
  
  replace(event.command,'%DAY',copy(date,1,2),false);
  replace(event.command,'%MONTH',copy(date,4,2),false);
  replace(event.command,'%YEAR',copy(date,7,2),false);
  replace(event.command,'%DATE',date,false);
  
  if next2run=1 then log('ð '+event.name+' ('+realdate+')')
   else log('= '+event.name);
  writeln(apbatch,'CALL '+event.command);
  writeln(apbatch,'GOTO START');
  close(apbatch);
 end else begin

  writeln(apbatch,'REBOOT');
  writeln(apbatch,'GOTO START');
  close(apbatch);
  erase(apdat);
  ioerror:=ioresult;

 end;
 
end. {APSCHED}
