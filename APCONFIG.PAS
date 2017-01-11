{$A+,B-,D-,E-,F-,G+,I-,L-,N-,O-,R-,S+,V-,X+}
{$M 16384,0,0}

uses
 test186,crt,dos,utility,data,random6;

const
 last:longint=0;
 yeskey='YOSJ';
 onoff:array [false..true] of string[3]=('Off','On ');
 parsetting:array [0..4] of string[5]=('None','Even','Odd','Mark','Space');

type
 menurec=array [0..20] of string[60];
 helprec=array [0..20] of string[70];
 pickact=(seekto,readrec,retmax);
 comport=record
  base:word;
  irq:byte;
  int:byte;
 end;

{$I lastrev.inc}
{$I apdefs.inc}
{$I runerr.inc}

var
 currsite:dialentry;
 dialfile:file of dialentry;
 currevent:schedentry;
 schedfile:file of schedentry;
 currmodem:modementry;
 modemfile:file of modementry;
 ioerror:integer;
 crc,firstcrc:word;
 exitsave:pointer;               {points to termination routine}

 thatsallfolks:boolean;          {time for bed?}

 setupfile:file of config;       {disk file for setup}
 oldsetup:config;

 sending:boolean;
 datelogged:boolean;
 limited:boolean;

 c:char;
 s,laststr:string;
 statusline,time,date,timer:string[80];
 mode,hour,min,sec:word;
 loop:word;
 firetime:string[10];
 curspeed:string[6];
 curport:string[1];
 mmchoice:byte;

 homepath:string[128];           {where .FON .SCH .MOD files are}

 option:menurec;                 {used by menu procedure}
 ophelp:helprec;
 menuname,oldhelp:string[80];

 logfile:text;

 pick:procedure(act:pickact;var s:string;var n:longint);
 pickletter:array ['A'..'Z'] of longint;

{**************************************************************************}

procedure encrconf;

var
 loop:word;

begin
 randseed:=18572;
 for loop:=1 to sizeof(config) do security[loop]:=security[loop] xor random(256);
end;

{**************************************************************************}

function getstatus:string;

var
 hun,year,month,day,dow:word;
 s1,s2,s3,s4,s5,s6:string[5];
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
 s3:=itos(year,4);
 date:=s1+'/'+s2+'/'+s3;
 temp:=' '+date+' ³ '+menuname;
 while length(temp)<71 do temp:=temp+' ';
 temp:=temp+time+' ';
 getstatus:=temp;
end;

{**************************************************************************}

procedure astatus; far;

var
 a:byte;
 sl:string[80];
 wmin,wmax:word;
 oc:boolean;
 ox,oy:byte;

begin
 ioerror:=ioresult;
 sl:=getstatus;
 if (sl<>statusline) or (helpline<>oldhelp) then begin
  oldhelp:=helpline;
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
  write(' ',helpline);
  clreol;
  gotoxy(1,1);
  centre(statusline);
  textattr:=a;
  windmin:=wmin;
  windmax:=wmax;
  gotoxy(ox,oy);
  if oc then cursoron;
 end;
end;

{**************************************************************************}

{$I apcrc.inc}

{**************************************************************************}

procedure log(s:string);

var
 temp:string;

begin
 temp:=getstatus;
 if not datelogged then begin
  writeln(logfile,firetime+' - APCONFIG started ('+date+')');
  datelogged:=true;
 end;
 s:=time+' '+s;
 if s[10]<>'+' then writeln(s);
 writeln(logfile,s);
end;

{**************************************************************************}

procedure exitroutine; far;

begin
 exitproc:=exitsave;
 textattr:=7;
 window(1,1,80,25);
 gotoxy(1,25);
 clreol;
 cursoron;
 if erroraddr<>nil then begin
  s:=runerror(exitcode);
  log('! Please report '+s);
  writeln;
  erroraddr:=nil;
 end;
 close(logfile);
 ioerror:=ioresult;
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

procedure menu(var default:byte;max:byte;getout:byte);

var
 loop,x,y,oldef,oldval,width,start:byte;
 c:char;
 endnow:boolean;
 s,hotkey:string;
 handle:word;

begin
 cursoroff;
 oldval:=default;
 endnow:=false;
 width:=0;
 for loop:=0 to max do
  if length(option[loop])>width then width:=length(option[loop]);
 inc(width);
 start:=(80-width) shr 1;
 handle:=openwin(start,3,start+width,max+4,option[0]);
 for loop:=1 to max do begin
  gotoxy(2,succ(loop));
  textcolor(colset.wsclr);
  write(option[loop][1]);
  textcolor(colset.wfclr);
  writeln(copy(option[loop],2,pred(length(option[loop]))));
 end;
 hotkey[0]:=#20;
 for loop:=1 to max do if option[loop]<>'' then hotkey[loop]:=upcase(option[loop][1])
                                           else hotkey[loop]:='þ';
 for loop:=succ(max) to 20 do hotkey[loop]:='þ';
 repeat
  gotoxy(1,succ(default));
  textcolor(colset.hfclr);
  textbackground(colset.hbclr);
  clreol;
  write(' ',option[default]);
  textcolor(colset.wfclr);
  textbackground(colset.wbclr);

  oldef:=default;
  helpline:=ophelp[default];
  repeat status until keypressed;
  c:=upcase(readkey);
  if c=#13 then endnow:=true;
  if c=#27 then begin
   endnow:=true;
   default:=getout;
  end;
  s:=hotkey;
  for loop:=1 to default do s[loop]:='þ';
  if pos(c,s)>0 then default:=pos(c,s);
  if (default=oldef) and (pos(c,hotkey)>0) then default:=pos(c,hotkey);
  if c=#0 then case readkey of
   #72:dec(default);
   #80:inc(default);
   #71:default:=1;
   #79:default:=max;
   #59:onlinehelp(option[0]);
   else;
  end;
  if not endnow then begin
   if default<1 then default:=max else
   if default>max then default:=1;
   if oldef<>default then begin
    gotoxy(1,succ(oldef));
    clreol;
    write(' ');
    textcolor(colset.wsclr);
    write(option[oldef][1]);
    textcolor(colset.wfclr);
    write(copy(option[oldef],2,pred(length(option[oldef]))));
   end;
  end;
 until endnow;
 closewin(handle);
end;

{**************************************************************************}

function io(s:string):boolean;

var
 temp:boolean;

begin
 ioerror:=ioresult;
 temp:=(ioerror=0);
 if not temp then winmsg('Error',runerror(ioerror)+' '+s);
 io:=temp;
end;

{**************************************************************************}

procedure pickdial(act:pickact;var s:string;var n:longint); far;

begin
 s:='';
 case act of
  seekto:seek(dialfile,n);
  readrec:begin
           read(dialfile,currsite);
           s:=currsite.name;
          end;
  retmax:n:=filesize(dialfile);
  else;
 end;
end;

{**************************************************************************}

procedure pickevent(act:pickact;var s:string;var n:longint); far;

begin
 s:='';
 case act of
  seekto:seek(schedfile,n);
  readrec:begin
           read(schedfile,currevent);
           s:=currevent.name;
          end;
  retmax:n:=filesize(schedfile);
  else;
 end;
end;

{**************************************************************************}

procedure pickmodem(act:pickact;var s:string;var n:longint); far;

begin
 s:='';
 case act of
  seekto:seek(modemfile,n);
  readrec:begin
           read(modemfile,currmodem);
           s:=currmodem.name;
          end;
  retmax:n:=filesize(modemfile);
  else;
 end;
end;

{**************************************************************************}

procedure pickinit;

var
 max,loop,temp:longint;
 c:char;
 s:string;

begin
 fillchar(pickletter,sizeof(pickletter),$FF);
 temp:=0;
 pick(seekto,s,temp);
 pick(retmax,s,max);
 for loop:=0 to pred(max) do begin
  pick(readrec,s,temp);
  c:=upcase(s[1]);
  if pickletter[c]=-1 then pickletter[c]:=loop;
 end;
end;

{**************************************************************************}

function picklist(title:string):longint;

var
 oldef,default,oldfirst,first,max,last,temp,loop:longint;
 handle:word;
 s,name:string;
 c:char;
 endnow:boolean;

begin
 pick(retmax,s,last); {Get last entry in the required file}
 if last>0 then begin
  endnow:=false;
  if last>=18 then max:=17 else max:=pred(last);
  handle:=openwin(18,3,62,max+5,title);
  cursoroff;
  oldfirst:=1;
  first:=0;
  default:=0;
  repeat

   if oldfirst<>first then begin
    gotoxy(1,1);
    clreol;
    pick(seekto,s,first);
    for loop:=first to max do begin
     writeln;
     pick(readrec,name,temp);
     option[loop-first]:=name;
     clreol;
     centre(name);
    end;
    oldfirst:=first;
    writeln;
    clreol;
   end;

   gotoxy(1,default+2-first);
   textcolor(colset.hfclr);
   textbackground(colset.hbclr);
   clreol;
   centre(option[default-first]);
   textcolor(colset.wfclr);
   textbackground(colset.wbclr);

   oldef:=default;
   repeat status until keypressed;
   c:=upcase(readkey);
   if c=#13 then endnow:=true;
   if c=#27 then begin
    endnow:=true;
    default:=-1;
   end;
   if c in ['A'..'Z'] then begin
    if pickletter[c]<>-1 then default:=pickletter[c];
    if default in [first..max] then
     {Don't do anything special}
    else
    if last<=18 then begin
     first:=0;
     max:=last;
    end else begin
     first:=default;
     max:=first+17;
     while max>=last do begin
      dec(first);
      dec(max);
     end;
    end;
    if first=oldfirst then c:=' ';
   end; 
   if c=#0 then case readkey of
    #72:begin
         dec(default);
         if (default<first) and (first>0) then begin
          dec(max);
          dec(first);
         end;
        end;
    #80:begin
         inc(default);
         if (default>max) and (max<pred(last)) then begin
          inc(max);
          inc(first);
         end;
        end;
    #71:default:=first;
    #79:default:=max;
    #81:begin
         loop:=0;
         while (max<pred(last)) and (loop<18) do begin
          inc(first);
          inc(max);
          inc(default);
          inc(loop);
         end;
         if oldef<first then oldef:=first;
        end;
    #73:begin
         loop:=0;
         while (first>0) and (loop<18) do begin
          dec(first);
          dec(max);
          dec(default);
          inc(loop);
         end;
         if oldef>max then oldef:=max;
        end;
    #59:onlinehelp(title);
    else;
   end;
   if not ((endnow) or (c in ['A'..'Z'])) then begin
    if default<first then default:=max else
    if default>max then default:=first;
    if oldef<>default then begin
     gotoxy(1,oldef+2-first);
     clreol;
     centre(option[oldef-first]);
    end;
   end;
  until endnow;
  closewin(handle);
  if default>=0 then begin
   pick(seekto,s,default);
   pick(readrec,s,temp);
   pick(seekto,s,default);
  end;
  picklist:=default;
 end else begin
  beep;
  picklist:=-1;
 end;
end;

{**************************************************************************}

procedure copyright;

begin
 window(8,15,80,24);
 writeln('ÚÄÄÄÄÄÄ· ÚÄÄÄÄÄ· ÚÄÄÄÄÄ· ÚÄÄÄÄÄ· ÚÄÄÄÄ·ÚÄ· ÚÄÄÄÄÄ· ÚÄÄÄ· ÚÄÄÄÄÄÄ·');
 writeln('³ ÖÄÄ¿ º ³ ÖÄ¿ º ³ ÖÄ¿ º ³ ÖÄ¿ º ³ Ö¿ º³ º ³ ÖÄÄÄ½ À¿ Ö½ ³ ÖÄÄÄÄ½');
 writeln('³ ÓÄÄÙ º ³ ÓÄÙ º ³ º ÀÄ½ ³ º ³ º ³ º³ º³ º ³ ÓÄ·    ³ º  ³ º ÚÄÄ·');
 writeln('³ ÖÄÄ¿ º ³ ÖÄÄÄ½ ³ º ÚÄ· ³ º ³ º ³ º³ º³ º ³ ÖÄ½    ³ º  ³ º À¿ º');
 writeln('³ º  ³ º ³ º     ³ ÓÄÙ º ³ ÓÄÙ º ³ º³ ÓÙ º ³ º     ÚÙ Ó· ³ ÓÄÄÙ º');
 writeln('ÀÄ½  ÀÄ½ ÀÄ½     ÀÄÄÄÄÄ½ ÀÄÄÄÄÄ½ ÀÄ½ÀÄÄÄÄ½ ÀÄ½     ÀÄÄÄ½ ÀÄÄÄÄÄÄ½');
 window(1,1,80,24);
 gotoxy(1,22);
 centre('APCONFIG version '+version); writeln;
 centre('Copyright (c) 1991 - 1993 Michael E. Ralphson, All Rights Reserved');
end;

{**************************************************************************}

procedure comports;

var
 s:string;
 handle:word;
 com:array [1..4] of word absolute $40:0;
 ok:array  [1..6] of boolean;
 loop:byte;

begin
 handle:=openwin(25,3,55,12,'Com-Ports');
 writeln;
 fillchar(ok,6,0);
 for loop:=1 to 4 do begin
  case com[loop] of
   $3F8:ok[1]:=true;
   $2F8:ok[2]:=true;
   $3E8:ok[3]:=true;
   $3F8:ok[4]:=true;
   $270:ok[6]:=true;
   else;
  end;
  if com[loop]=setup.com5.base then ok[5]:=true;
 end;
 for loop:=1 to 6 do begin
  str(loop,s);
  if ok[loop] then centre('COM '+s+' is Installed')
   else centre('COM '+s+' was not found');
  writeln;
 end;
 anykey(9,true);
 closewin(handle);
end;

{**************************************************************************}

procedure logmaint;

begin
end;

{**************************************************************************}

procedure delrec(s:string;psn:longint;recsize:word);

var
 f:file;
 buffer:array [1..4096] of byte;
 bread:word;

begin
 psn:=psn*recsize;
 assign(f,s);
 reset(f,1);
 if ioresult=0 then begin
  repeat
   seek(f,psn+recsize);
   blockread(f,buffer,4096,bread);
   seek(f,psn);
   blockwrite(f,buffer,bread);
   inc(psn,bread);
  until bread<4096;
  truncate(f);
  close(f);
 end;
end;

{**************************************************************************}

procedure editmodem(title:string;seekto:longint);

begin
 with currmodem do begin
  newdentry('APNS Modem type',1,'S',@name,40,0,'Name of this modem-type, manufacturer, speed etc');
  newdentry('Initialisation ',2,'S',@cmdinit,40,0,'Command necessary to initialise the modem');
  newdentry('Dial prefix    ',3,'S',@cmdpredial,40,0,'Modem dial prefix, use ATDP for Pulse, ATDT for Tone');
  newdentry('Auto-answer on ',4,'S',@cmdanswer,40,0,'Command necessary to enable auto-answer');
  newdentry('Hang up connect',5,'S',@cmdhangup,40,0,'Command necessary to hang-up the modem');
 end;
 dataentry(5,1,title);
 seek(modemfile,seekto);
 write(modemfile,currmodem);
 if seekto=last then inc(last);
end;

{**************************************************************************}

procedure addmodem;

begin
 fillchar(currmodem,sizeof(currmodem),0);
 currmodem.cmdinit:='ATZ|~~~AT&C1|';
 currmodem.cmdhangup:='~~~+++~~ATH0|';
 currmodem.cmdpredial:='ATDT';
 currmodem.cmdanswer:='ATS0=1|';
 editmodem('Add a Modem',last);
end;

{**************************************************************************}

procedure delmodem(filename:string);

var
 handle:word;
 picked:longint;
 c:char;

begin
 picked:=picklist('Delete');
 if picked>=0 then begin
  handle:=openwin(2,5,78,7,'Confirm Action');
  centre(#10'Do you want to delete '+currmodem.name+' (y/N) ?');
  c:=upcase(readkey);
  closewin(handle);
  if pos(c,yeskey)>0 then begin
   close(modemfile);
   delrec(filename,picked,sizeof(currmodem));
   reset(modemfile);
   dec(last);
   log('+ Modem '+currmodem.name+' deleted');
  end;
 end;
end;

{**************************************************************************}

procedure sortmodems;

type
 slist=array [1..300] of modementry;

var
 slptr:^slist;
 loop,howmany,handle:word;

{**************************************************************************}

procedure qsort(l,r:integer);

var
 i,j:integer;
 x,y:modementry;

begin
 i:=l;
 j:=r;
 x:=slptr^[(l+r) DIV 2];
 repeat
  while slptr^[i].name<x.name do inc(i);
  while x.name<slptr^[j].name do dec(j);
  if i<=j then begin
   y:=slptr^[i];
   slptr^[i]:=slptr^[j];
   slptr^[j]:=y;
   inc(i);
   dec(j);
  end;
 until i>j;
 if l<j then qsort(l,j);
 if i<r then qsort(i,r);
end;

{**************************************************************************}

begin
 reset(modemfile);
 howmany:=filesize(modemfile);
 if mem_avail>=4096 then begin
  handle:=mem_alloc(4096);
  slptr:=ptr(handle,0);
  for loop:=1 to howmany do read(modemfile,slptr^[loop]);
  qsort(1,howmany);
  reset(modemfile);
  for loop:=1 to howmany do write(modemfile,slptr^[loop]);
  mem_free(handle);
 end else winmsg('Error','Not enough memory for sort');
end;

{**************************************************************************}

procedure outputlist;

var
 filename:string;
 max,loop:longint;
 f:text;

begin
 reset(modemfile);
 max:=filesize(modemfile);
 filename:='';
 getstring(filename,60,'Output Filename');
 filename:=fexpand(filename);
 assign(f,filename);
 if exist(filename) then append(f) else
  rewrite(f);
 if io(filename) then begin
  for loop:=1 to max do begin
   read(modemfile,currmodem);
   writeln(f,currmodem.name);
   writeln(f,currmodem.cmdinit);
   writeln(f);
  end;
  close(f);
  reset(modemfile);
 end;
end;

{**************************************************************************}

procedure importlist;

var
 filename:string;
 max,loop:longint;
 f:text;

begin
 max:=filesize(modemfile);
 seek(modemfile,max);
 filename:='';
 getstring(filename,60,'Import Filename');
 filename:=fexpand(filename);
 assign(f,filename);
 reset(f);
 if io(filename) then begin
  while not eof(f) do begin
   fillchar(currmodem,sizeof(currmodem),0);
   readln(f,currmodem.name);
   readln(f,currmodem.cmdinit);
   if not eof(f) then readln(f);
   currmodem.cmdpredial:=setup.cmdpredial;
   currmodem.cmdanswer :='ATS0=1|';
   currmodem.cmdhangup :='~~~+++~~ATH0=1|';
   write(modemfile,currmodem);
  end;
  close(f);
  reset(modemfile);
  last:=filesize(modemfile);
 end;
end;

{**************************************************************************}

procedure modemmenu(auto:byte);

var
 omname:string[80];
 s:string;
 mmchoice:byte;
 picked:longint;

begin
 @pick:=@pickmodem;
 omname:=menuname;
 s:=homepath+'APNS.MOD';
 assign(modemfile,s);
 if exist(s) then reset(modemfile) else rewrite(modemfile);
 if io(s) then begin
  last:=filesize(modemfile);
  mmchoice:=1;
  repeat
   pickinit;
   if auto=0 then menuname:=omname+' \ MODEMS';
   status;
   option[0]:='Modems';
   option[1]:='Add Modem';
   option[2]:='Edit Modem';
   option[3]:='Delete Modem';
   option[4]:='Sort List';
   option[5]:='Output Text';
   option[6]:='Import Text';
   ophelp[1]:='Add a new modem to the APNS list';
   ophelp[2]:='Edit or view a defined modem entry';
   ophelp[3]:='Delete a modem from the APNS list';
   ophelp[4]:='Alphabetically sort the modem list';
   ophelp[5]:='Output the APNS Modem List to a text file';
   ophelp[6]:='Import the APNS Modem List from a text file';
   if auto=0 then menu(mmchoice,6,0) else mmchoice:=auto;
   if mmchoice<>1 then begin
    menuname:=menuname+' \ CHOOSE MODEM';
    helpline:='Use Up, Down, PgUp, PgDn, Home and End to locate modem';
   end;
   case mmchoice of
    255:if last>0 then begin
       picked:=picklist('Select');
       menuname:=menuname+' \ MODEMS';
       if picked>=0 then begin
        setup.cmdinit:=currmodem.cmdinit;
        setup.modemname:=currmodem.name;
        setup.cmdpredial:=currmodem.cmdpredial;
        setup.cmdanswer:=currmodem.cmdanswer;
        setup.cmdhangup:=currmodem.cmdhangup;
       end;
      end else winmsg('Error','There are no modems to select from');
    1:addmodem;
    2:if last>0 then begin
       picked:=picklist('Edit');
       menuname:=omname+' \ MODEMS';
       if picked>=0 then editmodem('Edit Modem',picked);
      end else winmsg('Error','There are no modems to edit');
    3:if last>0 then delmodem(s) else winmsg('Error','There are no modems to delete');
    4:sortmodems;
    5:outputlist;
    6:importlist;
    else;
   end;
   if auto<>0 then mmchoice:=0;
  until mmchoice=0;
  close(modemfile);
 end;
end;

{**************************************************************************}

procedure screensetup;

var
 x,y,colour,sschoice:byte;

begin
 sschoice:=1;
 menuname:=menuname+' \ SCREEN AND COLOUR';
 status;
 repeat
  option[0]:='Screen and Colour';
  option[1]:='Main foreground colour';
  option[2]:='Main background colour';
  option[3]:='Window foreground colour';
  option[4]:='Window background colour';
  option[5]:='Menu option colour';
  option[6]:='Window border style';
  option[7]:='Highlight foreground colour';
  option[8]:='Highlight background colour';
  option[9]:='Sound '+onoff[setup.sound];
  option[10]:='Direct screen writes '+onoff[setup.directvideo];
  option[11]:='Snow checking '+onoff[setup.snow];
  ophelp[1]:='Change standard text foreground colour';
  ophelp[2]:='Change standard text background colour';
  ophelp[3]:='Change window foreground colour';
  ophelp[4]:='Change window background colour';
  ophelp[5]:='Change menu option letter colour';
  ophelp[6]:='Change window border characters';
  ophelp[7]:='Change highlight bar foreground colour';
  ophelp[8]:='Change highlight bar background colour';
  ophelp[9]:='Toggle on / off bells and sound effects';
  ophelp[10]:='Turn off (BIOS writes) if direct writes cause problems';
  ophelp[11]:='Turn on snow checking for IBM made CGA adapters';
  menu(sschoice,11,0);
  case sschoice of
   1:colset.fclr:=succ(colset.fclr) and 15;
   2:colset.bclr:=succ(colset.bclr) and 7;
   3:colset.wfclr:=succ(colset.wfclr) and 15;
   4:colset.wbclr:=succ(colset.wbclr) and 7;
   5:colset.wsclr:=succ(colset.wsclr) and 15;
   6:setup.winstyle:=succ(setup.winstyle) mod 10;
   7:colset.hfclr:=succ(colset.hfclr) and 15;
   8:colset.hbclr:=succ(colset.hbclr) and 7;
   9:setup.sound:=not setup.sound;
  10:begin
      setup.directvideo:=not setup.directvideo;
      directvideo:=setup.directvideo;
     end;
  11:begin
      setup.snow:=not setup.snow;
      checksnow:=setup.snow;
     end;
   else;
  end;
  if (sschoice=1) or (sschoice=2) then begin
   colour:=(colset.bclr shl 4) or colset.fclr;
   for y:=2 to 24 do
    for x:=1 to 80 do dosptr^[y,x].at:=colour;
   textattr:=colour;
  end;
 until sschoice=0;
end;

{**************************************************************************}

procedure corridazo(var s:string);

begin
 if s[length(s)]<>'\' then s:=s+'\';
 fsplit(fexpand(s),dir,name,ext);
 if length(dir)>3 then delete(dir,length(dir),1);
 s:=dir;
end;

{ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ}

procedure filesetup;

begin
 menuname:=menuname+' \ FILE SETUP';
 newdentry('Outgoing Files',1,'S',@setup.updir,40,0,'Directory for outgoing files');
 newdentry('Incoming Files',2,'S',@setup.downdir,40,0,'Directory for incoming files');
 dataentry(2,1,'File Setup');
end;

{**************************************************************************}

procedure checkmod;

var
 s:string;

begin
 s:=setup.modemname;
 if pos('Modified ',s)=0 then s:='Modified '+s;
 move(s,setup.modemname,40);
end;

{**************************************************************************}

procedure modemsetup;

var
 mschoice:byte;
 s:string;
 loop:byte;
 i:integer;
 omn:string;

begin
 menuname:=menuname+' \ MODEM SETUP';
 omn:=menuname;
 mschoice:=1;
 status;
 repeat
  menuname:=omn;
  option[0]:='Modem Setup';
  option[1]:='Modem name : '+setup.modemname;
  option[2]:='Initialise : '+setup.cmdinit;
  option[3]:='Hang up    : '+setup.cmdhangup;
  option[4]:='Dial prefix: '+setup.cmdpredial;
  option[5]:='Answer call: '+setup.cmdanswer;
  ophelp[1]:='Name of the APNS modem-type in use';
  ophelp[2]:='Modem initialisation command';
  ophelp[3]:='Modem hang up command';
  ophelp[4]:='Modem dial prefix, use ATDP for Pulse, ATDT for Tone';
  ophelp[5]:='Modem auto-answer command';
  menu(mschoice,5,0);
  case mschoice of
   1:modemmenu(255);
   2:getstring(setup.cmdinit,40,'Initialise');
   3:getstring(setup.cmdhangup,40,'Hang Up');
   4:getstring(setup.cmdpredial,40,'Dial Prefix');
   5:getstring(setup.cmdanswer,40,'Auto-Answer');
   else;
  end;
  if mschoice>1 then checkmod;
 until mschoice=0;
end;

{**************************************************************************}

procedure apnssetup;

begin
 menuname:=menuname+' \ APNS SETUP';
 newdentry('Dial period in seconds   ',1,'b',@setup.dialtime,3,0,'Time to wait for a connect (seconds)');
 newdentry('Inter-dial pause minutes ',2,'b',@setup.dialpause,3,0,'Pause between consecutive calls to one site (minutes)');
 newdentry('Maximum redials of a site',3,'b',@setup.maxattempts,3,0,'Maximum number of calls to each site in one session');
 newdentry('Dial window start hour   ',4,'b',@setup.dialstart,2,0,'APNS auto-dial window start hour');
 newdentry('Dial window finish hour  ',5,'b',@setup.dialfinish,2,0,'APNS auto-dial window finish hour');
 newdentry('Wait window start hour   ',6,'b',@setup.waitstart,2,0,'APNS auto-answer window start hour');
 newdentry('Wait window finish hour  ',7,'b',@setup.waitfinish,2,0,'APNS auto-answer window finish hour');
 newdentry('Site identification code ',8,'X',@setup.site,4,0,'');
 newdentry('Connect delay in seconds ',9,'b',@setup.mnptime,3,0,'Number of seconds to delay before handshaking');
 newdentry('Exit after one call in   ',10,'o',@setup.exitafter,3,0,'Whether APNS will exit after being called once');
 newdentry('RTC time can be reset    ',11,'O',@setup.blockrtc,3,0,'Whether clock can be reset by other sites');
 newdentry('Difference from GMT / CET',12,'i',@setup.gmtdiff,5,0,'Difference (+/-) of local time to GMT in minutes');
 newdentry('Dial action',13,'S',@setup.okdial,70,0,'Command to execute after a successful call out to %SITE');
 newdentry('Wait action',14,'S',@setup.okwait,70,0,'Command to execute after a successful call in from %SITE');
 newdentry('Password   ',15,'S',@setup.password,40,0,'Session handshaking password');
 dataentry(15,1,'APNS Setup');
end;

{**************************************************************************}

procedure commsetup;

const
 dircon:array [false..true] of string[6]=('Modem','Direct');
 irqs:array [0..7] of byte=($FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F);

var
 cschoice:byte;
 tb1,tb2,bips:byte;
 temp:string;

begin
 cschoice:=1;
 menuname:=menuname+' \ COMMS SETUP';
 status;
 repeat
  str(setup.baud:6,curspeed);
  str(setup.comport,curport);
  option[0]:='Comms Setup';
  option[1]:='Bits per Second: '+curspeed;
  option[2]:='COM Port: '+curport;
  str(setup.length,temp);
  option[3]:='Data Length '+temp+' bits';
  option[4]:='Parity: '+parsetting[setup.parity];
  str(setup.stopbits,temp);
  option[5]:='Stop-bits: '+temp;
  option[6]:=dircon[setup.nulmodem]+' connection';
  option[7]:='COM 5 (User) Base '+w2hexs(setup.com5.base)+'h';
  for tb2:=0 to 7 do
   if setup.com5.irq=irqs[tb2] then tb1:=tb2;
  str(tb1,temp);
  option[8]:='COM 5 (User) IRQ  '+temp;
  option[9]:='COM 5 (user) Int. '+hexstr[succ(setup.com5.int)]+'h';
  option[10]:='Use FIFO buffers: '+yesno[setup.usefifos];
  ophelp[1]:='Maximum DTE speed (300 - 115200 bps)';
  ophelp[2]:='Communications port (IBM)';
  ophelp[3]:='Byte length (usually 8 bits)';
  ophelp[4]:='Parity setting (None, Even, Odd, Mark, Space)';
  ophelp[5]:='Stop bits (0,1,2) usually 1';
  ophelp[6]:='For null-modem links use Direct, normally use Modem';
  ophelp[7]:='I/O port base address for COM 5 (User)';
  ophelp[8]:='Hardware Interrupt (IRQ) for COM 5 (User)';
  ophelp[9]:='Software Interrupt (INT) for COM 5 (User)';
  ophelp[10]:='Allow use of FIFO buffers';
  menu(cschoice,10,0);
  case cschoice of
   1:begin
      setup.baud:=setup.baud*2;
      if setup.baud=153600 then setup.baud:=115200;
      if setup.baud=230400 then setup.baud:=300;
     end;
   2:begin
      inc(setup.comport);
      if setup.comport>8 then setup.comport:=1;
      str(setup.comport,curport);
     end;
   6:setup.nulmodem:=not setup.nulmodem;
   7:begin
      temp:=w2hexs(setup.com5.base);
      getstring(temp,4,'COM 5 (User) Base');
      while length(temp)<4 do temp:='0'+temp;
      setup.com5.base:=hexs2w(ucase(temp));
     end;
   8:begin
      inc(tb1);
      if tb1=8 then tb1:=0;
      setup.com5.irq:=irqs[tb1];
      setup.com5.int:=tb1+8;
     end;
   9:begin
      inc(setup.com5.int);
      if setup.com5.int=16 then setup.com5.int:=8;
     end;
   10:setup.usefifos:=not setup.usefifos;
    else;
  end;
 until cschoice=0;
end;

{**************************************************************************}

procedure writesetup;

begin
 crc:=0;
 crc16(crc,security,sizeof(security));
 if limited then crc:=not crc;
 setup.crc:=crc;
 encrconf;
 rewrite(setupfile);
 write(setupfile,setup);
 close(setupfile);
 if ioresult<>0 then winmsg('Error','Error writing APNS.CFG');
end;

{**************************************************************************}

procedure setupmenu;

var
 smchoice:byte;
 s:string;

begin
 smchoice:=1;
 s:=menuname;
 repeat
  menuname:=s+' \ SETUP MENU';
  status;
  option[0]:='Setup';
  option[1]:='Screen and colour';
  option[2]:='Filenames and paths';
  option[3]:='APNS control settings';
  option[4]:='Modem settings';
  option[5]:='Communications settings';
  option[6]:='Undo all changes';
  ophelp[1]:='Modify appearance of APNS';
  ophelp[2]:='Modify upload and download directories';
  ophelp[3]:='Modify APNS control settings';
  ophelp[4]:='Modify modem control settings';
  ophelp[5]:='Modify communication port parameters';
  ophelp[6]:='Restore configuration to undo modifications';
  menu(smchoice,6,0);
  case smchoice of
   1:screensetup;
   2:filesetup;
   3:apnssetup;
   4:modemsetup;
   5:commsetup;
   6:setup:=oldsetup;
   else;
  end;
 until smchoice=0;
end;

{**************************************************************************}

procedure sortsites;

type
 slist=array [1..250] of dialentry;

var
 slptr:^slist;
 loop,inner,howmany,handle:word;
 priority:string;

{**************************************************************************}

procedure qsort(l,r:integer);

var
 i,j:integer;
 x,y:dialentry;

begin
 i:=l;
 j:=r;
 x:=slptr^[(l+r) DIV 2];
 repeat
  while slptr^[i].name<x.name do inc(i);
  while x.name<slptr^[j].name do dec(j);
  if i<=j then begin
   y:=slptr^[i];
   slptr^[i]:=slptr^[j];
   slptr^[j]:=y;
   inc(i);
   dec(j);
  end;
 until i>j;
 if l<j then qsort(l,j);
 if i<r then qsort(i,r);
end;

{**************************************************************************}

begin
 reset(dialfile);
 howmany:=filesize(dialfile);
 if mem_avail>=4096 then begin
  handle:=mem_alloc(4096);
  slptr:=ptr(handle,0);
  for loop:=1 to howmany do read(dialfile,slptr^[loop]);
  qsort(1,howmany);
  reset(dialfile);
  for loop:=1 to howmany do write(dialfile,slptr^[loop]);
  mem_free(handle);
 end else winmsg('Error','Not enough memory for sorting');
end;

{**************************************************************************}

procedure editsite(title:string;seekto:longint);

const
 rmess:array [fail..success] of string[7]=('Fail','Partial','One-way','Success');
 cmess:array [everyday..never] of string[12]=('Always','When Sending','Never');

var
 handle:word;
 s:string;
 i:integer;
 emchoice,bips:byte;
 c:char;
 ask:boolean;

begin
 if currsite.control>never then currsite.control:=everyday;
 fillchar(currsite.other,sizeof(currsite.other),0);
 emchoice:=1;
 ask:=false;
 repeat
  option[0]:=title;
  option[1]:='Site Name   : '+currsite.name;
  option[2]:='Site Code   : '+currsite.site;
  option[3]:='Phone Number: '+currsite.number;
  str(currsite.bips:6,s);
  option[4]:='Modem Speed : '+s;
  s:=cmess[currsite.control];
  option[5]:='When To Dial: '+s;
  str(succ(currsite.session),s);
  option[6]:='Dial Session: '+s;
  option[7]:='Dial Prefix : '+currsite.prefix;
  str(currsite.days,s);
  option[8]:='Update Clock: '+yesno[currsite.sendtime];
  option[9]:='Days Failed : '+s;
  s:=rmess[currsite.today];
  option[10]:='Last Status : '+s;
  ophelp[1]:='Name used to identify site';
  ophelp[2]:='Site Identification, 4 characters';
  ophelp[3]:='Phone number including outside line codes and pauses';
  ophelp[4]:='Speed of the site modem';
  ophelp[5]:='Dial every day, when we have files to send, or never';
  ophelp[6]:='Dial session number, for use with multiple sessions';
  ophelp[7]:='Modem dial prefix, use ATDP for Pulse, ATDT for Tone';
  ophelp[8]:='Update site''s clock from this machine';
  ophelp[9]:='APNS will not dial any site unavailable for over 7 days';
  ophelp[10]:='Result of the last attempted dial to this site';
  menu(emchoice,10,0);
  case emchoice of
   1:getstring(currsite.name,40,'Name');
   2:begin
      getstring(currsite.site,4,'Site ID');
      while length(currsite.site)<4 do currsite.site:='0'+currsite.site;
      currsite.site:=ucase(currsite.site);
     end;
   3:getstring(currsite.number,40,'Phone Number');
   4:begin
      currsite.bips:=currsite.bips*2;
      if currsite.bips=153600 then currsite.bips:=115200;
      if currsite.bips=230400 then currsite.bips:=300;
     end;
   5:begin
      inc(currsite.control);
      if currsite.control>never then currsite.control:=everyday;
     end;
   6:begin
      str(succ(currsite.session),s);
      getstring(s,2,'Session Number (1-99)');
      val(s,currsite.session,i);
      if currsite.session>0 then dec(currsite.session);
     end;
   7:getstring(currsite.prefix,40,'Dial Prefix');
   8:currsite.sendtime:=not currsite.sendtime;
   9:begin
      currsite.days:=0;
      currsite.today:=success;
     end;
   else;
  end;
  if emchoice>0 then ask:=true;
 until emchoice=0;
 if ask then begin
  handle:=openwin(2,5,78,7,'Confirm Save');
  centre(#10+'Do you wish to save '+currsite.name+' (Y/n) ?');
  c:=upcase(readkey);
  closewin(handle);
  if c<>'N' then begin
   log('+ Site '+currsite.name+' modified');
   seek(dialfile,seekto);
   write(dialfile,currsite);
   if seekto=last then inc(last);
  end;
 end;
end;

{**************************************************************************}

procedure addsite;

begin
 fillchar(currsite,sizeof(currsite),0);
 currsite.prefix:=setup.cmdpredial;
 currsite.bips:=setup.baud;
 currsite.sendtime:=true;
 currsite.today:=success;
 editsite('Add Node',last);
end;

{**************************************************************************}

procedure deletesite(filename:string);

var
 handle:word;
 picked:longint;
 c:char;

begin
 picked:=picklist('Delete');
 if picked>=0 then begin
  handle:=openwin(2,5,78,7,'Confirm Delete');
  centre(#10+'Do you wish to delete '+currsite.name+' (y/N) ?');
  c:=upcase(readkey);
  closewin(handle);
  if c='Y' then begin
   close(dialfile);
   delrec(filename,picked,sizeof(currsite));
   reset(dialfile);
   dec(last);
   log('+ Site '+currsite.name+' deleted');
  end;
 end;
end;

{**************************************************************************}

procedure resetall(days:byte);

var
 loop:longint;

begin
 reset(dialfile);
 for loop:=0 to pred(last) do begin
  read(dialfile,currsite);
  currsite.days:=days;
  seek(dialfile,loop);
  write(dialfile,currsite);
 end;
 reset(dialfile);
end;

{**************************************************************************}

procedure dialdir;

var
 ddchoice:byte;
 picked:longint;
 omname:string[80];
 s:string;

begin
 @pick:=@pickdial;
 omname:=menuname;
 s:=homepath+'APNS.FON';
 assign(dialfile,s);
 if exist(s) then reset(dialfile) else rewrite(dialfile);
 if io(s) then begin
  pickinit;
  last:=filesize(dialfile);
  ddchoice:=1;
  repeat
   menuname:=omname+' \ NODE LIST';
   status;
   option[0]:='Node List';
   option[1]:='Add Node to the node list';
   option[2]:='Edit existing Node';
   option[3]:='Delete existing Node';
   option[4]:='Make all Nodes diallable';
   option[5]:='Make all Nodes undiallable';
   option[6]:='Sort Nodes by name';
   ophelp[1]:='Add an new node to the node list';
   ophelp[2]:='Change settings for any node';
   ophelp[3]:='Permanently remove any node';
   ophelp[4]:='Reset the days unreachable flags';
   ophelp[5]:='Set all days unreachable flags to 8';
   ophelp[6]:='Alphabetically sort the node list';
   menu(ddchoice,6,0);
   if (ddchoice=2) or (ddchoice=3) then
    helpline:='Use Up, Down, PgUp, PgDn, Home and End to locate site';
   case ddchoice of
    1:addsite;
    2:if last>0 then begin
       picked:=picklist('Edit');
       if picked>=0 then editsite('Edit Node',picked);
      end else winmsg('Error','There are no entries in the node-list');
    3:if last>0 then deletesite(s) else winmsg('Error','There are no entries in the node-list');
    4:begin
       resetall(0);
       log('+ All nodes made diallable');
      end;
    5:begin
       resetall(8);
       log('+ All nodes made undiallable');
      end;
    6:sortsites;
    else;
   end;
  until ddchoice=0;
  close(dialfile);
 end;
end;

{**************************************************************************}

procedure editevent(title:string;seekto:longint);

var
 handle:word;
 s:string;
 i:integer;
 emchoice,loop:byte;
 c:char;
 ask:boolean;

begin
 emchoice:=1;
 ask:=false;
 repeat
  option[0] :=title;
  option[1] :='Event Name : '+currevent.name;
  option[2] :='DOS Command: '+currevent.command;
  option[3] :='Priority   : '+currevent.priority;
  option[4] :='Sunday ..... '+yesno[currevent.okonday[0]];
  option[5] :='Monday ..... '+yesno[currevent.okonday[1]];
  option[6] :='Tuesday .... '+yesno[currevent.okonday[2]];
  option[7] :='Wednesday .. '+yesno[currevent.okonday[3]];
  option[8] :='Thursday ... '+yesno[currevent.okonday[4]];
  option[9] :='Friday ..... '+yesno[currevent.okonday[5]];
  option[10]:='Saturday ... '+yesno[currevent.okonday[6]];
  option[11]:='Once a day : '+yesno[currevent.onceonly];
  str(currevent.weekno,s);
  option[12]:='Week Number: '+s;
  option[13]:='Country    : '+itos(currevent.country,1);
  option[14]:='Date active: '+currevent.actdate;
  ophelp[1]:='Name used to identify event';
  ophelp[2]:='Event DOS Command, use %DATE, %DAY, %MONTH, %YEAR';
  ophelp[3]:='Four character event priority';
  ophelp[4]:='Does the event occur on a Sunday';
  ophelp[5]:='Does the event occur on a Monday';
  ophelp[6]:='Does the event occur on a Tuesday';
  ophelp[7]:='Does the event occur on a Wednesday';
  ophelp[8]:='Does the event occur on a Thursday';
  ophelp[9]:='Does the event occur on a Friday';
  ophelp[10]:='Does the event occur on a Saturday';
  ophelp[11]:='Does the event only run once per day';
  ophelp[12]:='Week number for the event (1-52). Specify one or more days as well';
  ophelp[13]:='Country Code for this event (32,33,44 etc)';
  ophelp[14]:='Date for the event (DD/MM/YY), Wildcards [??/10/??] or ENDMONTH';
  menu(emchoice,14,0);
  case emchoice of
   1:getstring(currevent.name,60,'Event Name');
   2:getstring(currevent.command,60,'Event DOS Command');
   3:begin
      getstring(currevent.priority,4,'Event Priority');
      currevent.priority:=ucase(currevent.priority);
     end;
  4..10:currevent.okonday[emchoice-4]:=not currevent.okonday[emchoice-4];
  11:currevent.onceonly:=not currevent.onceonly;
  12:begin
      str(currevent.weekno,s);
      getstring(s,2,'Week No');
      val(s,currevent.weekno,i);
      if currevent.weekno>52 then currevent.weekno:=0;
     end;
  13:begin
      str(currevent.country,s);
      getstring(s,3,'Country Code (32,33,44 etc)');
      val(s,currevent.country,i);
     end;
  14:begin
      getstring(currevent.actdate,8,'Event Date (DD/MM/YY) or ENDMONTH');
      currevent.actdate:=ucase(currevent.actdate);
      if currevent.actdate<>'ENDMONTH' then begin
       for loop:=1 to length(currevent.actdate) do
        if not (currevent.actdate[loop] in ['0'..'9','?','/']) then
         currevent.actdate[loop]:='/';
      end;
      if currevent.actdate<>'' then begin
       for loop:=0 to 6 do currevent.okonday[loop]:=true;
       while length(currevent.actdate)<8 do currevent.actdate:=currevent.actdate+'?';
      end;
     end;
   else;
  end;
  if emchoice>0 then ask:=true;
 until emchoice=0;
 if ask then begin
  handle:=openwin(2,5,78,7,'Confirm Save');
  centre(#10+'Do you wish to save '+currevent.name+' (Y/n) ?');
  c:=upcase(readkey);
  closewin(handle);
  if c<>'N' then begin
   log('+ Event '+currevent.name+' modified');
   seek(schedfile,seekto);
   write(schedfile,currevent);
   if seekto=last then inc(last);
  end;
 end;
end;

{**************************************************************************}

procedure addevent;

begin
 fillchar(currevent,sizeof(currevent),0);
 for loop:=0 to 6 do currevent.okonday[loop]:=true;
 editevent('Add Event',last);
end;

{**************************************************************************}

procedure delevent(filename:string);

var
 handle:word;
 picked:longint;
 c:char;

begin
 picked:=picklist('Delete');
 if picked>=0 then begin
  handle:=openwin(2,5,78,7,'Confirm Delete');
  centre(#10+'Do you wish to delete '+currevent.name+' (y/N) ?');
  c:=upcase(readkey);
  closewin(handle);
  if c='Y' then begin
   close(schedfile);
   delrec(filename,picked,sizeof(currevent));
   reset(schedfile);
   dec(last);
   log('+ Event '+currevent.name+' deleted');
  end;
 end;
end;

{**************************************************************************}

procedure sortsched;

type
 slist=array [1..250] of schedentry;

var
 slptr:^slist;
 loop,inner,howmany,handle:word;
 priority:string;

{**************************************************************************}

procedure qsort(l,r:integer);

var
 i,j:integer;
 x,y:schedentry;

begin
 i:=l;
 j:=r;
 x:=slptr^[(l+r) DIV 2];
 repeat
  while slptr^[i].priority<x.priority do inc(i);
  while x.priority<slptr^[j].priority do dec(j);
  if i<=j then begin
   y:=slptr^[i];
   slptr^[i]:=slptr^[j];
   slptr^[j]:=y;
   inc(i);
   dec(j);
  end;
 until i>j;
 if l<j then qsort(l,j);
 if i<r then qsort(i,r);
end;

{**************************************************************************}

begin
 reset(schedfile);
 howmany:=filesize(schedfile);
 if mem_avail>=4096 then begin
  handle:=mem_alloc(4096);
  slptr:=ptr(handle,0);
  for loop:=1 to howmany do read(schedfile,slptr^[loop]);
  qsort(1,howmany);
  reset(schedfile);
  if howmany<27 then begin
   priority:='AAAA';
   for loop:=1 to howmany do begin
    slptr^[loop].priority:=priority;
    for inner:=1 to 4 do inc(priority[inner]);
   end;
  end;
  for loop:=1 to howmany do write(schedfile,slptr^[loop]);
  mem_free(handle);
 end else winmsg('Error','Not enough memory for sorting');
end;

{**************************************************************************}

procedure schedmenu;

var
 omname:string[80];
 s:string;
 smchoice:byte;
 picked:longint;

begin
 @pick:=@pickevent;
 omname:=menuname;
 s:=homepath+'APNS.SCH';
 assign(schedfile,s);
 if exist(s) then reset(schedfile) else rewrite(schedfile);
 if io(s) then begin
  pickinit;
  last:=filesize(schedfile);
  smchoice:=1;
  repeat
   menuname:=omname+' \ SCHEDULER';
   status;
   option[0]:='Schedule';
   option[1]:='Add Event';
   option[2]:='Edit Event';
   option[3]:='Delete Event';
   option[4]:='Sort Events';
   ophelp[1]:='Add a new event to the current schedule';
   ophelp[2]:='Edit or view a defined schedule event';
   ophelp[3]:='Delete an event from the schedule list';
   ophelp[4]:='Sort event order by priorities';
   menu(smchoice,4,0);
   if (smchoice=2) or (smchoice=3) then begin
    menuname:=menuname+' \ CHOOSE EVENT';
    helpline:='Use Up, Down, PgUp, PgDn, Home and End to locate event';
   end;
   case smchoice of
    1:addevent;
    2:if last>0 then begin
       picked:=picklist('Edit');
       menuname:=omname+' \ SCHEDULER';
       if picked>=0 then editevent('Edit Event',picked);
      end else winmsg('Error','There are no events to edit');
    3:if last>0 then delevent(s) else winmsg('Error','There are no events to delete');
    4:sortsched;
    5:
    else;
   end;
  until smchoice=0;
  close(schedfile);
 end;
end;

{**************************************************************************}

begin

 exitsave:=exitproc;
 exitproc:=@exitroutine;

 menuname:='Retrieving configuration...';

 textattr:=setup.fclr;
 clrscr;
 copyright;
 gotoxy(1,23);
 statusline:='';
 helpline:='';
 @status:=@astatus;
 status;
 firetime:=time;

 datelogged:=false;

 s:=homepath+'APNS.LOG';
 assign(logfile,s);
 if exist(s) then append(logfile) else rewrite(logfile);
 if not io(s) then exit;

 s:=homepath+'APNS.CFG';

 assign(setupfile,s);
 reset(setupfile);
 read(setupfile,setup);
 close(setupfile);
 errcheck(' while reading '+s);

 limited:=false;
 encrconf;
 crc:=0;
 crc16(crc,security,sizeof(security));
 if crc<>setup.crc then begin
  crc:=not crc;
  limited:=true;
 end;
 if crc<>setup.crc then begin
  log('! Configuration file has been tampered with');
  exit;
 end;
 firstcrc:=setup.crc;

 {This is the first place the variable SETUP is referenced}

 oldsetup:=setup;

 directvideo:=setup.directvideo;
 checksnow:=setup.snow;
 utilbeep:=setup.sound;

 fillchar(option,sizeof(option),0);

 if scrmode=CO80 then move(setup.fclr,colset,7) else move(monset,colset,7);
 textcolor(colset.fclr);
 textbackground(colset.bclr);

 status;
 copyright;

 thatsallfolks:=false;

 if setup.password<>'' then begin
  helpline:='Enter the APNS security password';
  status;
  invisible:=true;
  s:='';
  getstring(s,40,'Password');
  s:=ucase(s);
  if s<>setup.password then begin
   log('+ Incorrect password');
   winmsg('Password','Password Incorrect');
   exit;
  end;
  invisible:=false;
 end;

 if paramcount>0 then begin
  s:=ucase(paramstr(1));
  if s='SETDIR' then begin
   setup.updir:=fexpand('\APNS\SEND');
   setup.downdir:=fexpand('\APNS\RECV');
  end;
 end;

 cursoroff;

 mmchoice:=1;
 repeat
  menuname:='APCONFIG';
  helpline:='';
  status;
  option[0]:='Main Menu';
  option[1]:='Configuration';
  option[2]:='Node List';
  option[3]:='Scheduler';
  option[4]:='Modem List';
  option[5]:='Com-Ports';
  option[6]:='Trim Log File';
  ophelp[1]:='Configuration sub-menus';
  ophelp[2]:='Node-list management menus';
  ophelp[3]:='Event schedule management menu';
  ophelp[4]:='Modem-list maintenance menu';
  ophelp[5]:='Locate standard IBM Com-Ports';
  ophelp[6]:='Remove old information from APNS.LOG';
  menu(mmchoice,5,0);
  case mmchoice of
   1:setupmenu;
   2:dialdir;
   3:schedmenu;
   4:modemmenu(0);
   5:comports;
   6:logmaint;
   else;
  end;
 until mmchoice=0;

 writesetup;
 if setup.crc<>firstcrc then log('+ Configuration modified');

end. {APCONFIG}
