{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}

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
 esc=#27;                   {j, f, m, a, m, j, j, a, s, o, n, d}
 dim:array [1..12] of byte=(31,28,31,30,31,30,31,31,30,31,30,31);

var
 exitsave:pointer;
 s:string;
 logname:string[128];
 time,date:string[20];
 dir:dirstr;
 name:namestr;                   {fsplit of invoked name}
 ext:extstr;
 dow,year,month,day:word;

 logfile:text;
 ioerror:integer;

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
 time:=pad(w1)+':'+pad(w2)+':'+pad(w3);
 getdate(year,month,day,dow);
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
 if erroraddr=nil then writeln(#13+#10+'Thanks for using APSCHED') else begin
  str(exitcode,s);
  log(logfile,'! Abnormal program termination. Please report error '+s);
  writeln;
 end;
 maketd;
 writeln(logfile);
 writeln(logfile,'  APSCHED exitted at '+time+' on the '+date);
 close(logfile);
 exitproc:=exitsave;
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

procedure errors;

var
 s:string[20];
 dosex:word;
 doser:integer;

begin
 dosex:=dosexitcode;
 doser:=doserror;
 append(logfile);
 if dosex<>0 then begin
  str(dosex,s);
  log(logfile,'? Program exitted with error code '+s);
 end;
 if doser<>0 then begin
  case doser of
   0:s:='no error';
   2:s:='file not found';
   3:s:='path not found';
   5:s:='access denied';
   6:s:='invalid handle';
   8:s:='not enough memory';
  10:s:='invalid environment';
  11:s:='invalid format';
  18:s:='no more files';
  else s:='unknown error';
  end;
  log(logfile,'! DOS reports '+s);
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
 temp:=pos(#32,command);
 if temp>0 then begin
  tail:=copy(command,succ(temp),length(command)-temp);
  delete(command,temp,succ(length(command)-temp));
 end else tail:='';
 old:=command;
 oldt:=tail;

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
  writeln(#10+'Loading secondary command processor.'+lf);
  tail:='/C '+old+space+tail;
  if old+oldt='' then tail:='';
  command:=getenv('COMSPEC');
 end else writeln(lf+'Running external program.'+lf);
 writeln('Command line: '+command+space+tail+lf);
 close(logfile);
 exec(command,tail);
 errors;
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

{ APSCHED }

var
 c:char;
 loop:longint;
 currentop:optype;
 event:schedentry;
 schedfile:file of schedentry;
 doit:boolean;
 week:byte;
 daysofar:word;

begin

 exitsave:=exitproc;
 exitproc:=@exitroutine;

 s:=fexpand(paramstr(0));
 fsplit(s,dir,name,ext);
 logname:=dir+'APNS.LOG';
 assign(logfile,logname);
 if exist(logname) then append(logfile) else rewrite(logfile);

 maketd;
 writeln(logfile);
 writeln(logfile,stringof('Э',79));
 writeln(logfile);
 writeln(logfile,'  APSCHED started at '+time+' on the '+date);

 if year mod 4=0 then inc(dim[2]); {Leap years}
 daysofar:=0;
 for loop:=1 to pred(month) do inc(daysofar,dim[loop]);
 inc(daysofar,day);
 week:=daysofar div 7;
 if (daysofar/7)>week then inc(week);

 s:=dir+'APNS.SCH';
 assign(schedfile,s);
 reset(schedfile);

 ioerror:=ioresult;
 if ioerror<>0 then begin
  str(ioerror,s);
  log(logfile,'Error '+s+' reading schedule file');
  exit;
 end;

 clrscr;

 copyright;

 writeln(#10'Today is the ',date,' (day number ',daysofar,', week number ',week,')');

 for loop:=1 to filesize(schedfile) do begin
  read(schedfile,event);
  maketd;
  doit:=false;
  case event.operation of
   dated:if event.actdate=date then doit:=true;
   endmonth:if day=dim[month] then doit:=true;
   startmonth:if day=1 then doit:=true;
   sun:if dow=0 then doit:=true;
   mon:if dow=1 then doit:=true;
   tue:if dow=2 then doit:=true;
   wed:if dow=3 then doit:=true;
   thu:if dow=4 then doit:=true;
   fri:if dow=5 then doit:=true;
   sat:if dow=6 then doit:=true;
   weekno:if (dow=1) and (event.weekno=week) then doit:=true;
   else;
  end;
  if doit then begin
   log(logfile,'');
   log(logfile,'  Starting event: '+event.comment);
   run(event.command);
  end;
 end;

 reset(schedfile);

 for loop:=1 to filesize(schedfile) do begin
  read(schedfile,event);
  if event.operation=every then begin
   log(logfile,'');
   log(logfile,'  Starting event: '+event.comment);
   run(event.command);
  end;
 end;

 close(schedfile);

end. {APNS}