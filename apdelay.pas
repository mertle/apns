{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 4096,0,0}
program apdelay;

{Program for the shop system to wait and allow PC-Anywhere support calls
 before going into APNS WAIT at the specified time}

uses crt,dos;

type
 comport=record
  base:word;
  IRQ:byte;
  int:byte;
 end;

 waitstyle=(for_begin,for_end);

{$I apdefs.inc}

var
 setupfile:file of config;       {disk file for setup}
 apdat:file of longint;
 cfgname,s,homepath,homedir:string;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 {r:registers;}
 loop,error:byte;
 nextevent:longint;
 waitmode:waitstyle;

{**************************************************************************}

procedure encrconf;

var
 loop:word;

begin
 randseed:=18572;
 for loop:=1 to sizeof(config) do security[loop]:=security[loop] xor random(256);
end;

{*************************************************************************}

function itos(i:word;n:byte):string;

var
 temp:string;
 loop:byte;

begin
 str(i:n,temp);
 for loop:=1 to length(temp) do if temp[loop]=' ' then temp[loop]:='0';
 itos:=temp;
end;

{*************************************************************************}

function time:string;

var
 hour,min,sec,hun:word;
 temp:string;

begin
 gettime(hour,min,sec,hun);
 time:=itos(hour,2)+':'+itos(min,2)+':'+itos(sec,2);
end;

{*************************************************************************}

procedure log(s:string);

var
 logfile:text;

begin
 assign(logfile,homepath+'APNS.LOG');
 append(logfile);
 if ioresult<>0 then rewrite(logfile);
 writeln(logfile,time+' '+s);
 close(logfile);
end;

{*************************************************************************}

procedure bounce;

var
 x,y:byte;
 dx,dy:shortint;
 chour,hour,min,sec,hun:word;
 password:string;
 getout,secret,testfor:boolean;

begin
 error:=0;
 {r.ah:=1;
 r.cx:=$2020;
 intr($10,r);}
 password:='';
 chour:=setup.waitfinish;
 if chour<setup.waitstart then inc(chour,24);
 textattr:=7;
 clrscr;
 x:=succ(random(79));
 y:=succ(random(25));
 dx:=1;
 dy:=1;
 repeat
  gotoxy(x,y);
  write('ø');
  delay(90);
  gotoxy(x,y);
  write(' ');
  x:=x+dx;
  y:=y+dy;
  if x>79 then begin
   x:=78;
   dx:=-1;
  end;
  if x<1 then begin
   x:=2;
   dx:=1;
  end;
  if y>25 then begin
   y:=24;
   dy:=-1;
  end;
  if y<1 then begin
   y:=2;
   dy:=1;
  end;

  if keypressed then password:=password+upcase(readkey);
  getout:=pos('DOS',password)>0;
  secret:=pos('SOD',password)>0;

  gettime(hour,min,sec,hun);

  if waitmode=for_begin then begin
   if hour<setup.waitstart then inc(hour,24);
   testfor:=(hour in [setup.waitstart..chour])
  end else begin
   if hour>0 then dec(hour)
   else hour:=23;
   testfor:=(hour=setup.waitfinish);
  end;

 until (testfor) or (getout) or (secret);

 {r.ah:=1;
 r.cx:=$0607;
 intr($10,r);}
 clrscr;
 if getout then begin
  error:=255;
  log('* Support call made through ApDelay');
  writeln('Type EXIT to return to Scheduler, rebooting runs first event');
  exec(getenv('COMSPEC'),'');
 end;
 if secret then begin
  log('* Support window closed by remote');
 end;
end;

{*************************************************************************}

begin
 s:=fexpand(paramstr(0));
 fsplit(s,dir,name,ext);
 homepath:=dir;
 homedir:=copy(dir,1,pred(length(dir)));
 waitmode:=for_begin;
 if paramcount>0 then begin
  s:=paramstr(1);
  for loop:=1 to length(s) do s[loop]:=upcase(s[loop]);
  if s='END' then waitmode:=for_end;
 end;
 cfgname:=homepath+'APNS.CFG';
 assign(setupfile,cfgname);
 reset(setupfile);
 read(setupfile,setup);
 close(setupfile);
 {if ioresult<>0 then exit;}

 encrconf;

 s:=homepath+'APSCHED.DAT';
 assign(apdat,s);
 reset(apdat);
 read(apdat,nextevent);
 close(apdat);
 if ioresult=0 then begin
  dec(nextevent);
  if nextevent<0 then nextevent:=0;
  rewrite(apdat);
  write(apdat,nextevent);
  close(apdat);
 end;
 writeln('Poo');
 repeat
  chdir(homedir);
  if ioresult<>0 then;
  bounce;
 until error=0;
 inc(nextevent);
 rewrite(apdat);
 write(apdat,nextevent);
 close(apdat);
 if ioresult<>0 then;
end.
