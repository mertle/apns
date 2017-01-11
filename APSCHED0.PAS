{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 8192,0,0}

program APSCHED;

uses
 crt,dos;

{$I lastrev.inc}

{$I english.inc}

{$I apdefs.inc}

const
 space=#32;
 cr=#13;
 lf=#10;
 esc=#27;                  {j, f, m, a, m, j, j, a, s, o, n, d}
 dim:array [1..12] of byte=(31,28,31,30,31,30,31,31,30,31,30,31);
 nod:array [0..6] of string[6]=('Sun','Mon','Tues','Wednes','Thurs','Fri','Satur');
 pass:string[20]='DOS';

var
 exitsave:pointer;
 s:string;
 logname:string[128];
 time,date:string[20];
 dir:dirstr;
 name:namestr;                   {fsplit of invoked name}
 ext:extstr;
 dow,year,month,day:word;
 apbatch,logfile:text;
 apdat:file of longint;
 next2run:longint;
 ioerror:integer;
 r:registers;
 daysofar:word;

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

function pad(n:word):string;

var
 temp:string;

begin
 str(n:2,temp);
 if temp[1]=' ' then temp[1]:='0';
 pad:=temp;
end;

{**************************************************************************}

procedure maketd;

var
 w1,w2,w3,w4:word;

begin
 gettime(w1,w2,w3,w4);
 getdate(year,month,day,dow);
 if year mod 4=0 then inc(dim[2]); {Leap years}
 if w1<7 then begin
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
 time:=pad(w1)+':'+pad(w2)+':'+pad(w3);
 date:=pad(day)+'/'+pad(month)+'/'+pad(year mod 100);
end;

{**************************************************************************}

procedure log(var f:text;s:string);

begin
 writeln(s);
 writeln(f,s);
end;

{**************************************************************************}

{$F+}procedure exitroutine;{$F-}

var
 x,y:byte;

begin
 x:=wherex;
 y:=wherey;
 window(1,1,80,25);
 gotoxy(1,25);
 clreol;
 textattr:=7;
 gotoxy(x,y);
 if erroraddr<>nil then begin
  str(exitcode,s);
  log(logfile,'! Abnormal program termination. Please report error '+s);
  writeln;
 end;
 maketd;
 log(logfile,'');
 log(logfile,'  APSCHED exitted at '+time+' on the '+date);
 close(logfile);
 exitproc:=exitsave;
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
writeln(cr+lf+'Automated Event Scheduler Module (APSCHED)');
writeln(
  cr+lf+'Version '+version+' (Last Revision '+lastrev+')',
  cr+lf+'Copyright (c) 1991 Michael E. Ralphson, All Rights Reserved');
end;

{**************************************************************************}

procedure getsneaky;

var
 s:string;
 loop,inner:byte;
 c:char;

begin
 writeln;
 s:='';
 loop:=1;
 repeat
  write('Clearing memory: ',loop*64:3,'Kb'#13);
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
 until (loop>10) or (s=pass);
 writeln;
 if s=pass then begin
  textattr:=textattr or 128;
  writeln(#13#10'When you are finished in DOS you must REBOOT!');
  textattr:=7;
  writeln(logfile,'* DOS accessed from ApSched');
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
  halt(0);
 end;
end;

{**************************************************************************}

{ APSCHED }

var
 c:char;
 loop:longint;
 event:schedentry;
 schedfile:file of schedentry;
 doit:boolean;
 week:byte;
 adname:string;

begin

 exitsave:=exitproc;
 exitproc:=@exitroutine;

 copyright;

 s:=fexpand(paramstr(0));
 fsplit(s,dir,name,ext);
 logname:=dir+'APNS.LOG';
 assign(logfile,logname);
 if exist(logname) then append(logfile) else rewrite(logfile);

 adname:=dir+'APSCHED.DAT';

 assign(apdat,adname);
 reset(apdat);
 read(apdat,next2run);
 close(apdat);
 if ioresult<>0 then next2run:=0;

 writeln(#10'Entering the Schedule file at entry number ',next2run);

 maketd;
 writeln(logfile);
 writeln(logfile,stringof('Э',79));
 writeln(logfile);
 writeln(logfile,'  APSCHED started at '+time+' on the '+date);

 daysofar:=0;
 for loop:=1 to pred(month) do inc(daysofar,dim[loop]);
 inc(daysofar,day);
 week:=daysofar div 7;
 if (daysofar/7)>week then inc(week);

 writeln(#10'Today is ',nod[dow],'day the ',date,' (Day Number ',daysofar,', Week Number ',week,')');

 getsneaky;

 writeln;

 s:=dir+'APNS.SCH';
 assign(schedfile,s);
 reset(schedfile);

 writeln;
 ioerror:=ioresult;
 if ioerror<>0 then begin
  str(ioerror,s);
  log(logfile,'! Error '+s+' reading schedule file');
  exit;
 end;

 doit:=false;

 if next2run<filesize(schedfile) then begin
  repeat
   seek(schedfile,next2run);
   read(schedfile,event);
   maketd;
   for loop:=1 to length(event.actdate) do
    if event.actdate[loop]='?' then event.actdate[loop]:=date[loop];

   if copy(event.actdate,1,2)='99' then begin
    if (day=dim[month]) or ((dow=6) and (day=pred(dim[month]))) then
     move(date[1],event.actdate[1],2);
   end;

   doit:=false;

   {The new decision making process goes here}

   if event.okonday[dow] then doit:=true;

   if not doit then log(logfile,'* Could not run '+event.comment+' on this day of the week');

   if event.weekno>0 then
    if event.weekno<>week then begin
     doit:=false;
     log(logfile,'* Could not run '+event.comment+' on this week number');
    end;

   if event.actdate<>'' then
    if event.actdate<>date then begin
     doit:=false;
     log(logfile,'* Could not run '+event.comment+' on this date');
    end;

{   if event.lastrun=daysofar then begin
    doit:=false;
    log(logfile,'* '+event.comment+' has already been run today');
   end;}

   inc(next2run);
  until (next2run>=filesize(schedfile)) or (doit);
 end;


 {Update was here, see below}

 close(schedfile);
 assign(apbatch,dir+'APSCHED.BAT');
 rewrite(apbatch);
 writeln(apbatch,'@ECHO OFF');
 writeln(apbatch,':START');
 writeln(apbatch,dir[1]+':');
 s:=dir;
 dec(s[0]);
 writeln(apbatch,'CD '+s);
 writeln(apbatch,'APSCHED0.EXE');

 if doit then begin
  assign(apdat,adname);
  rewrite(apdat);
  write(apdat,next2run);
  close(apdat);
  log(logfile,'');
  log(logfile,'  '+date+' '+time+' : '+event.comment);
  writeln(apbatch,'CALL '+event.command);
  writeln(apbatch,'GOTO START');
  close(apbatch);
 end else begin

  writeln(apbatch,'REBOOT');
  close(apbatch);
  erase(apdat);
  ioerror:=ioresult;

 end;

end. {APNS}

 if doit then begin
  event.lastrun:=daysofar;
  seek(schedfile,pred(next2run));     {Update lastrun counter for this event}
  write(schedfile,event);             {Write any changes to the schedule file}
 end;
