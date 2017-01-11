{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,655360}

uses
 crt,dos;

const
 max_menu_items=20;
 space=' ';
 cr=#13;
 lf=#10;
 esc=#27;
 nul=#0;
 last:longint=0;

{$I lastrev.inc}

{$I english.inc}

{$I apdefs.inc}

type
 screen=array [1..3840] of byte;
 menurec=array [0..max_menu_items] of string[60];
 helprec=array [0..max_menu_items] of string[70];

var
 current,temp:dialentry;
 dialfile:file of dialentry;
 currevent,tempevent:schedentry;
 schedfile:file of schedentry;
 ioerror:integer;
 crc:word;
 checksum:byte;
 dosptr:^screen;                 {screen memory pointer for windows}
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
 statusline,time,date,timer:string[80];
 hour,min,sec:word;
 loop:word;
 oldcolour:byte;
 mode:byte;
 curspeed:string[5];
 curport:string[1];
 mmchoice:byte;

 homepath,                       {where .EXT .PRO .CAP files are}
 curpath,                        {directory for upload download etc}
 oldpath,
 curfile:string[128];
 curname:string[8];

 dir:dirstr;
 name:namestr;                   {fsplit of invoked name}
 ext:extstr;

 option:menurec;                 {used by menu procedure}
 ophelp:helprec;
 menuname,helpline,oldhelp:string[80];
 cursor_spec:word;

 oldx,oldy:byte;                 {window stuff}
 wmin,wmax:word;

 save,store,scratch:screen;

 cfgfile:file of config;
 logfile:text;

{**************************************************************************}

function ucase(s:string):string;

var
 temp:string;
 loop:byte;

begin
 temp:='';
 for loop:=1 to length(s) do temp:=temp+upcase(s[loop]);
 ucase:=temp;
end;

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
 gotoxy(succ(((succ(lo(windmax)-lo(windmin)))-length(s)) div 2),wherey);
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

procedure swapem(var save:screen);

begin
 scratch:=dosptr^;
 dosptr^:=save;
 save:=scratch;
end;

{**************************************************************************}

function getstatus:string;

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
 temp:=' '+date+' ³ '+menuname;
 while length(temp)<71 do temp:=temp+' ';
 temp:=temp+time+' ';
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
  write(helpline);
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

{$I crc16.inc}

{**************************************************************************}

procedure log(var f:text;s:string);

begin
 writeln(s);
 writeln(f,s);
 status;
end;

{**************************************************************************}

{$F+}procedure exitroutine;{$F-}

begin
 clrscr;
 window(1,1,80,25);
 normvideo;
 clrscr;
 cursoron;
 if erroraddr<>nil then begin
  str(exitcode,s);
  log(logfile,'! Abnormal program termination. Please report error '+s);
  writeln;
 end;
 writeln(logfile);
 writeln(logfile,'  APCONFIG exited at '+time+' on the '+date);
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

{*************************************************************************}

procedure openwin(left,up,right,down:byte;
                  var save:screen;
                  var oldx,oldy:byte;
                  border:boolean;
                  title:string);

var
 loop:word;
 box:frametype;

begin
 oldcolour:=textattr;
 save:=dosptr^;
 oldx:=wherex;
 oldy:=wherey;
 wmin:=windmin;
 wmax:=windmax;
 if border then begin
  textcolor(setup.wfclr);
  textbackground(setup.wbclr);
 end else normvideo;
 window(left,succ(up),right,succ(down));
 clrscr;
 windmin:=wmin;
 windmax:=wmax;
 box:=frame[setup.winstyle];
 if border then begin
  gotoxy(pred(left),pred(up));
  writeln(box[1],stringof(box[2],succ(right-left)),box[3]);
  if title<>'' then begin

   gotoxy(succ(left)+((right-left)-(length(title)+4)) shr 1,pred(up));

   write(box[7],space,title,space,box[8]);
  end;
  for loop:=up to down do begin
   gotoxy(pred(left),loop);
   write(box[4]);
   gotoxy(succ(right),loop);
   write(box[4]);
  end;
  gotoxy(pred(left),succ(down));
  write(box[5],stringof(box[2],succ(right-left)),box[6]);
 end;
 window(left,succ(up),right,succ(down));
end;

{**************************************************************************}

procedure closewin(var save:screen;x,y:byte);

var
 loop:word;

begin
 swapem(save);
 windmin:=wmin;
 windmax:=wmax;
 status;
 gotoxy(x,y);
 textattr:=oldcolour;
end;

{**************************************************************************}

procedure onlinehelp(title:string);

var
 f:text;
 c:char;
 stopnow:boolean;

begin
 stopnow:=false;
 assign(f,homepath+curname+'.HLP');
 reset(f);
 if ioresult=0 then begin
  repeat
   readln(f,s);
  until (pos('.'+title,s)>0) or seekeof(f);
  if not(eof(f)) then begin
   openwin(3,3,78,23,save,oldx,oldy,true,title+' Help');
   repeat
    readln(f,s);
    if s='.more' then begin
     write(' * Press any key for more *');
     repeat status until keypressed;
     c:=readkey;
     if c=ESC then stopnow:=true;
     clrscr;
    end else if s<>'.' then writeln(space,s);
   until (eof(f)) or (s='.') or (stopnow);
   close(f);
   if not stopnow then begin
    repeat status until keypressed;
    while keypressed do c:=readkey;
   end;
   closewin(save,oldx,oldy);
  end;
 end;
end;

{**************************************************************************}

procedure menu(var default:byte;max:byte;getout:byte);

var
 loop:byte;
 width,start:byte;
 x,y:byte;
 wmin,wmax:word;
 c:char;
 endnow:boolean;
 oldef,oldval,oldcol:byte;
 s:string;

begin
 cursoroff;
 oldval:=default;
 endnow:=false;
 width:=0;
 for loop:=0 to max do
  if length(option[loop])>width then width:=length(option[loop]);
 while width<length(option[0])+4 do inc(width);
 inc(width);
 start:=(80-width) div 2;
 openwin(start,3,start+width,max+4,store,x,y,true,option[0]);
 for loop:=1 to max do begin
  gotoxy(2,succ(loop));
  writeln(option[loop]);
 end;
 repeat

  gotoxy(1,succ(default));
  textcolor(setup.hfclr);
  textbackground(setup.hbclr);
  clreol;
  write(space+option[default]);
  textcolor(setup.wfclr);
  textbackground(setup.wbclr);

  oldef:=default;
  helpline:=ophelp[default];
  repeat status until keypressed;
  c:=readkey;
  if c=cr then endnow:=true;
  if c=esc then begin
   endnow:=true;
   default:=getout;
  end;
  if c=nul then case readkey of
   #72:dec(default);
   #80:inc(default);
   #71:default:=1;
   #79:default:=max;
   #24:begin
        swapem(save);
        repeat until keypressed;
        while keypressed do c:=readkey;
        swapem(save);
       end;
   #59:begin
        oldcol:=oldcolour;
        wmin:=windmin;
        wmax:=windmax;
        window(1,2,80,24);
        onlinehelp(option[0]);
        oldcolour:=oldcol;
        windmin:=wmin;
        windmax:=wmax;
       end;
   else;
  end;
  if not endnow then begin
   if default<1 then default:=max else
   if default>max then default:=1;
   if oldef<>default then begin
    gotoxy(1,succ(oldef));
    clreol;
    write(space+option[oldef]);
   end;
  end;
 until endnow;
 closewin(store,x,y);
 cursoron;
end;

{**************************************************************************}

procedure getstring(var s:string;max:byte;title:string);

var
 x,y,edge:byte;
 len:byte absolute s;
 old:string;
 c:char;
 fkey:boolean;

begin
 edge:=(76-max) shr 1;
 if max<length(title) then edge:=(70-length(title)) shr 1;
 openwin(2+edge,5,78-edge,7,save,oldx,oldy,true,title);
 gotoxy(1,2);
 old:=s;
 write(s);
 y:=wherey;
 x:=wherex;
 repeat
  gotoxy(x,y);
  repeat status until keypressed;
  fkey:=false;
  c:=readkey;
  case c of
     #0:if keypressed then fkey:=true;
     #8:if x>1 then begin
         delete(s,pred(x),1);
         dec(x);
         gotoxy(1,y);
         write(s);
         clreol;
        end else beep;
   #32..#126:if len<max then begin
         insert(c,s,x);
         inc(x);
         if x<=len then begin
          gotoxy(1,y);
          write(s);
         end else write(c);
        end else beep;
   #13,#27:;
   else beep;
  end;
  if fkey then begin
   c:=readkey;
   case c of
    #83:if x<=len then begin
         delete(s,x,1);
         gotoxy(1,y);
         write(s);
         clreol;
        end else beep;
    #75:if x>1 then dec(x) else beep;
    #77:if x<=len then inc(x) else beep;
    #71:x:=1;
    #79:x:=succ(len);
    else beep;
   end;
  end;
 until c in [#27,#13];
 if c=#27 then s:=old;
 closewin(save,oldx,oldy);
end;

{**************************************************************************}

procedure copyright;

begin
 gotoxy(1,22);
 centre('APCONFIG v'+version+', ('+lastrev+') Copyright (c) 1991 Michael E. Ralphson');
end;

{**************************************************************************}

const
 onoff:array [false..true] of string[2]=('ff','n');

procedure screensetup;

var
 colour,sschoice:byte;

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
  option[5]:='Window border style';
  option[6]:='Highlight foreground colour';
  option[7]:='Highlight background colour';
  option[8]:='Sound O'+onoff[setup.sound];
  option[9]:='Direct screen writes O'+onoff[setup.direct];
  option[10]:='Snow checking O'+onoff[setup.snow];
  ophelp[1]:='Change standard text foreground colour';
  ophelp[2]:='Change standard text background colour';
  ophelp[3]:='Change window foreground colour';
  ophelp[4]:='Change window background colour';
  ophelp[5]:='Change window border characters';
  ophelp[6]:='Change highlight bar foreground colour';
  ophelp[7]:='Change highlight bar background colour';
  ophelp[8]:='Toggle on / off bells and sound effects';
  ophelp[9]:='Turn off (BIOS writes) if direct writes cause problems';
  ophelp[10]:='Turn on snow checking for IBM made CGA adapters';
  colour:=(setup.bclr shl 4) or setup.fclr;
  for loop:=81 to 1920 do dosptr^[loop shl 1]:=colour;
  textattr:=colour;
  menu(sschoice,10,0);
  case sschoice of
   1:setup.fclr:=succ(setup.fclr) and 15;
   2:setup.bclr:=succ(setup.bclr) and 7;
   3:setup.wfclr:=succ(setup.wfclr) and 15;
   4:setup.wbclr:=succ(setup.wbclr) and 7;
   5:setup.winstyle:=succ(setup.winstyle) mod 10;
   6:setup.hfclr:=succ(setup.hfclr) and 15;
   7:setup.hbclr:=succ(setup.hbclr) and 7;
   8:setup.sound:=not setup.sound;
   9:begin
      setup.direct:=not setup.direct;
      directvideo:=setup.direct;
     end;
   10:begin
       setup.snow:=not setup.snow;
       checksnow:=setup.snow;
      end;
   else;
  end;
 until sschoice=0;
end;

{**************************************************************************}

procedure filesetup;

var
 temp:string;
 fschoice:byte;

begin
 fschoice:=1;
 menuname:=menuname+' \ FILE SETUP';
 status;
 repeat
  option[0]:='File Setup';
  option[1]:='Upload path  : '+setup.updir;
  option[2]:='Download path: '+setup.downdir;
  ophelp[1]:='Directory for outgoing files';
  ophelp[2]:='Directory for incoming files';
  menu(fschoice,2,0);
  case fschoice of
   1:begin
      getstring(setup.updir,40,'Upload Path');
      if setup.updir[length(setup.updir)]<>'\'
       then setup.updir:=setup.updir+'\';
      fsplit(fexpand(setup.updir),dir,name,ext);
      if length(dir)>3 then delete(dir,length(dir),1);
      setup.updir:=dir;
     end;
   2:begin
      getstring(setup.downdir,40,'Download Path');
      if setup.downdir[length(setup.downdir)]<>'\'
       then setup.downdir:=setup.downdir+'\';
      fsplit(fexpand(setup.downdir),dir,name,ext);
      if length(dir)>3 then delete(dir,length(dir),1);
      setup.downdir:=dir;
     end;
   else;
  end;
 until fschoice=0;
end;

{**************************************************************************}

procedure modemsetup;

var
 mschoice:byte;
 s:string;
 loop:byte;

begin
 menuname:=menuname+' \ APNS SETUP';
 mschoice:=1;
 status;
 repeat
  option[0]:='Apns Setup';
  option[1]:='Initialise : '+setup.cmdinit;
  option[2]:='Hang up    : '+setup.cmdhangup;
  option[3]:='Dial prefix: '+setup.cmdpredial;
  option[4]:='Answer call: '+setup.cmdanswer;
  str(setup.dialtime,s);
  option[5]:='Dial time : '+s;
  str(setup.dialpause,s);
  option[6]:='Dial pause: '+s;
  str(setup.maxattempts,s);
  option[7]:='Maximum re-dials: '+s;
  str(setup.dialstart:2,s);
  if s[1]=' ' then s[1]:='0';
  option[8]:='Make calls from (hour):  '+s;
  str(setup.dialfinish:2,s);
  if s[1]=' ' then s[1]:='0';
  option[9]:='Make calls until (hour): '+s;
  str(setup.waitstart:2,s);
  if s[1]=' ' then s[1]:='0';
  option[10]:='Answer calls from (hour):  '+s;
  str(setup.waitfinish:2,s);
  if s[1]=' ' then s[1]:='0';
  option[11]:='Answer calls until (hour): '+s;
  option[12]:='Site Identification: '+setup.site;
  str(setup.mnptime:2,s);
  if s[1]=' ' then s[1]:='0';
  option[13]:='Connect delay time:  '+s;
  option[14]:='Dial action: '+setup.okdial;
  option[15]:='Wait action: '+setup.okwait;
  option[16]:='Exit after one call: O'+onoff[setup.exitafter];
  option[17]:='Password: '+setup.password;
  ophelp[1]:='Modem initialisation command';
  ophelp[2]:='Modem hang up command';
  ophelp[3]:='Default dialling prefix';
  ophelp[4]:='Modem auto-answer command';
  ophelp[5]:='Time to wait for a connect (seconds)';
  ophelp[6]:='Pause between consecutive dials of one number (minutes)';
  ophelp[7]:='Maximum number of re-dials of one site in an evening';
  ophelp[8]:='APNS auto-dial window start hour (before midnight)';
  ophelp[9]:='APNS auto-dial window finish hour (after midnight)';
  ophelp[10]:='APNS auto-answer window start hour (before midnight)';
  ophelp[11]:='APNS auto-answer window finish hour (after midnight)';
  ophelp[12]:='Site Identification code, 4 characters';
  ophelp[13]:='Number of seconds to delay before handshaking';
  ophelp[14]:='Command to execute after a successful poll';
  ophelp[15]:='Command to execute after a successful call';
  ophelp[16]:='Whether APNS will exit after being called once';
  ophelp[17]:='Session handshaking password';
  menu(mschoice,17,0);
  case mschoice of
   1:getstring(setup.cmdinit,40,'Initialise');
   2:getstring(setup.cmdhangup,40,'Hang Up');
   3:getstring(setup.cmdpredial,40,'Dial Prefix');
   4:getstring(setup.cmdanswer,40,'Auto-Answer');
   5:begin
      inc(setup.dialtime,5);
      if setup.dialtime>60 then setup.dialtime:=20;
     end;
   6:begin
      inc(setup.dialpause);
      if setup.dialpause>10 then setup.dialpause:=1;
     end;
   7:begin
      inc(setup.maxattempts);
      if setup.maxattempts>20 then setup.maxattempts:=1;
     end;
   8:begin
      inc(setup.dialstart);
      if setup.dialstart=24 then setup.dialstart:=0;
     end;
   9:begin
      inc(setup.dialfinish);
      if setup.dialfinish=24 then setup.dialfinish:=0;
     end;
  10:begin
      inc(setup.waitstart);
      if setup.waitstart=24 then setup.waitstart:=0;
     end;
  11:begin
      inc(setup.waitfinish);
      if setup.waitfinish=24 then setup.waitfinish:=0;
     end;

{$IFDEF debug}

   12:begin
       getstring(setup.site,4,'Site Identification');
       while length(setup.site)<4 do setup.site:='0'+setup.site;
       for loop:=1 to 4 do setup.site[loop]:=upcase(setup.site[loop]);
      end;

{$ENDIF}

   13:begin
       inc(setup.mnptime);
       if setup.mnptime=11 then setup.mnptime:=0;
      end;
   14:getstring(setup.okdial,70,'Use %SITE as parameter');
   15:getstring(setup.okwait,70,'Use %SITE as parameter');
   16:setup.exitafter:=not setup.exitafter;
   17:begin
       getstring(setup.password,40,'Session handshake password');
       setup.password:=ucase(setup.password);
      end;
   else;
  end;
 until mschoice=0;
end;

{**************************************************************************}

procedure commsetup;

const
 bpsrate:array [1..7] of word=(300,1200,2400,4800,9600,19200,38400);
 parsetting:array [0..2] of string[4]=('None','Even','Odd');
 dircon:array [false..true] of string[6]=('Modem','Direct');

var
 cschoice:byte;
 bips:byte;
 temp:string;

begin
 cschoice:=1;
 menuname:=menuname+' \ COMMS SETUP';
 status;
 repeat
  str(setup.baud:5,curspeed);
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
  ophelp[1]:='Maximum speed (computer to modem)';
  ophelp[2]:='Communications port (IBM)';
  ophelp[3]:='Byte length (usually 8 bits)';
  ophelp[4]:='Parity setting (None, Even, Odd) usually None';
  ophelp[5]:='Stop bits (0,1,2) usually 1';
  ophelp[6]:='For null-modem links use Direct, normally use Modem';
  menu(cschoice,6,0);
  case cschoice of
   1:begin
      bips:=1;
      while setup.baud<>bpsrate[bips] do inc(bips);
      inc(bips);
      if bips>7 then bips:=1;
      setup.baud:=bpsrate[bips];
      str(bpsrate[bips]:5,curspeed);
     end;
   2:begin
      inc(setup.comport);
      if setup.comport>4 then setup.comport:=1;
      str(setup.comport,curport);
     end;
   4:begin
      inc(setup.parity);
      if setup.parity>2 then setup.parity:=0;
     end;
   3:begin
      inc(setup.length);
      if setup.length>8 then setup.length:=7;
     end;
   5:begin
      inc(setup.stopbits);
      if setup.stopbits>2 then setup.stopbits:=1;
     end;
   6:setup.nulmodem:=not setup.nulmodem;
   else;
  end;
 until cschoice=0;
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
  option[4]:='Communications settings';
  option[5]:='Write setup to disk';
  ophelp[1]:='Modify appearance of APNS';
  ophelp[2]:='Modify upload and download directories';
  ophelp[3]:='Modify dial strings et cetera';
  ophelp[4]:='Modify communication port parameters';
  ophelp[5]:='Make settings permanent';
  menu(smchoice,5,0);
  case smchoice of
   1:screensetup;
   2:filesetup;
   3:modemsetup;
   4:commsetup;
   5:begin
      crc:=0;
      for loop:=1 to sizeof(config)-2 do crc16(checksum,crc,security[loop]);
      setup.crc:=crc;
      assign(setupfile,cfgname);
      rewrite(setupfile);
      write(setupfile,setup);
      close(setupfile);
      if ioresult>0 then write(#7);
     end;
   else;
  end;
 until smchoice=0;
end;

{**************************************************************************}

function picklist(title:string):longint;

var
 oldef,default,oldfirst,first,max:longint;
 x,y:byte;
 wmin,wmax:word;
 c:char;
 endnow:boolean;
 loop,oldcol:byte;
 s:string;

begin
 menuname:=menuname+' \ CHOOSE SITE';
 helpline:='Use Up, Down, PgUp, PgDn, Home and End to locate site';
 status;
 cursoroff;
 endnow:=false;
 if last>=18 then max:=17 else max:=pred(last);
 openwin(18,4,62,max+6,store,x,y,true,title);
 oldfirst:=1;
 first:=0;
 default:=0;
 repeat

  if oldfirst<>first then begin
   gotoxy(1,1);
   clreol;
   seek(dialfile,first);
   for loop:=first to max do begin
    writeln;
    read(dialfile,current);
    option[loop-first]:=current.name;
    clreol;
    centre(current.name);
   end;
   oldfirst:=first;
   writeln;
   clreol;
  end;

  gotoxy(1,default+2-first);
  textcolor(setup.hfclr);
  textbackground(setup.hbclr);
  clreol;
  centre(option[default-first]);
  textcolor(setup.wfclr);
  textbackground(setup.wbclr);

  oldef:=default;
  repeat status until keypressed;
  c:=readkey;
  if c=cr then endnow:=true;
  if c=esc then begin
   endnow:=true;
   default:=-1;
  end;
  if c=nul then case readkey of
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
   #24:begin
        swapem(save);
        repeat until keypressed;
        while keypressed do c:=readkey;
        swapem(save);
       end;
   #59:begin
        oldcol:=oldcolour;
        wmin:=windmin;
        wmax:=windmax;
        window(1,2,80,24);
        onlinehelp(title);
        oldcolour:=oldcol;
        windmin:=wmin;
        windmax:=wmax;
       end;
   else;
  end;
  if not endnow then begin
   if default<first then default:=max else
   if default>max then default:=first;
   if oldef<>default then begin
    gotoxy(1,oldef+2-first);
    clreol;
    centre(option[oldef-first]);
   end;
  end;
 until endnow;
 closewin(store,x,y);
 cursoron;
 if default>=0 then begin
  seek(dialfile,default);
  read(dialfile,current);
 end;
 picklist:=default;
end;

{**************************************************************************}

procedure editmenu(title:string;seekto:longint);

const
 mess:array [fail..success] of string[7]=('Fail','Partial','One-way','Success');

var
 emchoice,bips:byte;
 s:string;
 c:char;
 ask:boolean;

begin
 emchoice:=1;
 ask:=false;
 repeat
  option[0]:=title;
  option[1]:='Site Name: '+current.name;
  option[2]:='Site ID  : '+current.site;
  option[3]:='Phone Number: '+current.number;
  option[4]:='Dial Prefix : '+current.prefix;
  str(current.days,s);
  option[5]:='Days Failed : '+s;
  s:=mess[current.today];
  option[6]:='Last night  : '+s;
  ophelp[1]:='Name used to identify site';
  ophelp[2]:='Site Identification, 4 characters';
  ophelp[3]:='Phone number including outside line codes and pauses';
  ophelp[4]:='Dial prefix used for this site';
  ophelp[5]:='APNS will not dial any site unavailable for over 7 days';
  ophelp[6]:='Result of last dial attempt to this site';
  menu(emchoice,6,0);
  case emchoice of
   1:getstring(current.name,40,'Name');
   2:begin
      getstring(current.site,4,'Site ID');
      while length(current.site)<4 do current.site:='0'+current.site;
      for loop:=1 to 4 do current.site[loop]:=upcase(current.site[loop]);
     end;
   3:getstring(current.number,40,'Phone Number');
   4:getstring(current.prefix,40,'Dial Prefix');
   5:current.days:=0;
   else;
  end;
  if emchoice>0 then ask:=true;
 until emchoice=0;
 if ask then begin
  openwin(2,5,78,7,save,oldx,oldy,true,'Confirm Save');
  centre(lf+'Do you wish to save the current entry (Y/n) ?');
  c:=upcase(readkey);
  closewin(save,oldx,oldy);
  if c<>'N' then begin
   seek(dialfile,seekto);
   write(dialfile,current);
   if seekto=last then inc(last);
  end;
 end;
end;

{**************************************************************************}

procedure addmenu;

begin
 fillchar(current.name,sizeof(current),#0);
 current.prefix:=setup.cmdpredial;
 editmenu('Add an entry',last);
end;

{**************************************************************************}

procedure deletemenu;

var
 c:char;
 picked:longint;

begin
 picked:=picklist('Delete');
 if picked>=0 then begin
  openwin(2,5,78,7,save,oldx,oldy,true,'Confirm Delete');
  centre(lf+'Do you wish to delete '+current.name+' (y/N) ?');
  c:=upcase(readkey);
  closewin(save,oldx,oldy);
  if c='Y' then begin
   dec(last);
   seek(dialfile,last);
   read(dialfile,current);
   seek(dialfile,picked);
   write(dialfile,current);
   seek(dialfile,last);
   truncate(dialfile);
  end;
 end;
end;

{**************************************************************************}

procedure resetall;

var
 loop:longint;

begin
 reset(dialfile);
 for loop:=0 to pred(last) do begin
  read(dialfile,current);
  current.days:=0;
  seek(dialfile,loop);
  write(dialfile,current);
 end;
 reset(dialfile);
end;

{*************************************************************************}

procedure dialdir;

var
 ddchoice:byte;
 picked:longint;
 omname:string[80];

begin
 omname:=menuname;
 assign(dialfile,homepath+'APNS.FON');
 reset(dialfile);
 if ioresult<>0 then begin
  rewrite(dialfile);
  reset(dialfile);
 end;
 last:=filesize(dialfile);
 ddchoice:=1;
 repeat
  menuname:=omname+' \ DIALLING DIRECTORY';
  status;
  option[0]:='Dialling Directory';
  option[1]:='Add a new entry';
  option[2]:='Edit an existing entry';
  option[3]:='Delete an existing entry';
  option[4]:='Make all sites diallable';
  ophelp[1]:='Add an new site to the dialling directory';
  ophelp[2]:='Change settings for any site';
  ophelp[3]:='Permanently remove any site';
  ophelp[4]:='Reset the days unreachable flags';
  menu(ddchoice,4,0);
  case ddchoice of
   1:addmenu;
   2:if last>0 then begin
      picked:=picklist('Edit');
      if picked>=0 then editmenu('Edit an entry',picked);
     end else beep;
   3:if last>0 then deletemenu else beep;
   4:resetall;
   else;
  end;
 until ddchoice=0;
 close(dialfile);
end;

{**************************************************************************}

function pickevent(title:string):longint;

var
 oldef,default,oldfirst,first,max:longint;
 x,y:byte;
 wmin,wmax:word;
 c:char;
 endnow:boolean;
 loop,oldcol:byte;
 s:string;

begin
 menuname:=menuname+' \ CHOOSE EVENT';
 helpline:='Use Up, Down, PgUp, PgDn, Home and End to locate event';
 status;
 cursoroff;
 endnow:=false;
 if last>=18 then max:=17 else max:=pred(last);
 openwin(18,4,62,max+6,store,x,y,true,title);
 oldfirst:=1;
 first:=0;
 default:=0;
 repeat

  if oldfirst<>first then begin
   gotoxy(1,1);
   clreol;
   seek(schedfile,first);
   for loop:=first to max do begin
    writeln;
    read(schedfile,currevent);
    option[loop-first]:=currevent.comment;
    clreol;
    centre(currevent.comment);
   end;
   oldfirst:=first;
   writeln;
   clreol;
  end;

  gotoxy(1,default+2-first);
  textcolor(setup.hfclr);
  textbackground(setup.hbclr);
  clreol;
  centre(option[default-first]);
  textcolor(setup.wfclr);
  textbackground(setup.wbclr);

  oldef:=default;
  repeat status until keypressed;
  c:=readkey;
  if c=cr then endnow:=true;
  if c=esc then begin
   endnow:=true;
   default:=-1;
  end;
  if c=nul then case readkey of
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
   #24:begin
        swapem(save);
        repeat until keypressed;
        while keypressed do c:=readkey;
        swapem(save);
       end;
   #59:begin
        oldcol:=oldcolour;
        wmin:=windmin;
        wmax:=windmax;
        window(1,2,80,24);
        onlinehelp(title);
        oldcolour:=oldcol;
        windmin:=wmin;
        windmax:=wmax;
       end;
   else;
  end;
  if not endnow then begin
   if default<first then default:=max else
   if default>max then default:=first;
   if oldef<>default then begin
    gotoxy(1,oldef+2-first);
    clreol;
    centre(option[oldef-first]);
   end;
  end;
 until endnow;
 closewin(store,x,y);
 cursoron;
 if default>=0 then begin
  seek(schedfile,default);
  read(schedfile,currevent);
 end;
 pickevent:=default;
end;

{**************************************************************************}

procedure editevent(title:string;seekto:longint);

const
 yesno:array [false..true] of string[3]=('No','Yes');

var
 emchoice:byte;
 s:string;
 c:char;
 ask:boolean;

begin
 emchoice:=1;
 ask:=false;
 repeat
  option[0]:=title;
  option[1]:='Event Name: '+currevent.comment;
  option[2]:='Command : '+currevent.command;
  option[3]:='Priority: '+currevent.priority;
  option[4]:='Monday    '+yesno[currevent.okonday[1]];
  option[5]:='Tuesday   '+yesno[currevent.okonday[2]];
  option[6]:='Wednesday '+yesno[currevent.okonday[3]];
  option[7]:='Thursday  '+yesno[currevent.okonday[4]];
  option[8]:='Friday    '+yesno[currevent.okonday[5]];
  option[9]:='Saturday  '+yesno[currevent.okonday[6]];
  option[10]:='Sunday    '+yesno[currevent.okonday[0]];
  str(currevent.weekno,s);
  option[11]:='Week No: '+s;
  option[12]:='Date   : '+currevent.actdate;
  ophelp[1]:='Name used to identify event';
  ophelp[2]:='Command used to start event';
  ophelp[3]:='Four character event priority';
  ophelp[4]:='Does the event occur on a Monday';
  ophelp[5]:='Does the event occur on a Tuesday';
  ophelp[6]:='Does the event occur on a Wednesday';
  ophelp[7]:='Does the event occur on a Thursday';
  ophelp[8]:='Does the event occur on a Friday';
  ophelp[9]:='Does the event occur on a Saturday';
  ophelp[10]:='Does the event occur on a Sunday';
  ophelp[11]:='Week number for the event (1-52). Specify one or more days as well';
  ophelp[12]:='Date for the event (DD/MM/YY). Use a ? for a wildcard [??/10/??]';
  menu(emchoice,12,0);
  case emchoice of
   1:getstring(currevent.comment,60,'Event Name');
   2:getstring(currevent.command,60,'Event DOS Command');
   3:begin
      getstring(currevent.priority,4,'Event Priority');
      currevent.priority:=ucase(currevent.priority);
     end;
   4:currevent.okonday[1]:=not currevent.okonday[1];
   5:currevent.okonday[2]:=not currevent.okonday[2];
   6:currevent.okonday[3]:=not currevent.okonday[3];
   7:currevent.okonday[4]:=not currevent.okonday[4];
   8:currevent.okonday[5]:=not currevent.okonday[5];
   9:currevent.okonday[6]:=not currevent.okonday[6];
  10:currevent.okonday[0]:=not currevent.okonday[0];
  11:begin
      inc(currevent.weekno);
      if currevent.weekno>52 then currevent.weekno:=0;
     end;
  12:getstring(currevent.actdate,8,'Event Date (DD/MM/YY)');
   else;
  end;
  if emchoice>0 then ask:=true;
 until emchoice=0;
 if ask then begin
  openwin(2,5,78,7,save,oldx,oldy,true,'Confirm Save');
  centre(lf+'Do you wish to save the current entry (Y/n) ?');
  c:=upcase(readkey);
  closewin(save,oldx,oldy);
  if c<>'N' then begin
   seek(schedfile,seekto);
   write(schedfile,currevent);
   if seekto=last then inc(last);
  end;
 end;
end;

{**************************************************************************}

procedure addevent;

begin
 fillchar(currevent,sizeof(currevent),#0);
 editevent('Add a new Event',last);
end;

{**************************************************************************}

procedure delevent;

var
 c:char;
 picked:longint;

begin
 picked:=pickevent('Delete');
 if picked>=0 then begin
  openwin(2,5,78,7,save,oldx,oldy,true,'Confirm Delete');
  centre(lf+'Do you wish to delete '+current.name+' (y/N) ?');
  c:=upcase(readkey);
  closewin(save,oldx,oldy);
  if c='Y' then begin
   dec(last);
   seek(schedfile,last);
   read(schedfile,currevent);
   seek(schedfile,picked);
   write(schedfile,currevent);
   seek(schedfile,last);
   truncate(schedfile);
  end;
 end;
end;

{***************************************************************************}

procedure sortem;

begin
end;

{***************************************************************************}

procedure schedmenu;

var
 omname:string[80];
 smchoice:byte;
 picked:longint;

begin
 omname:=menuname;
 assign(schedfile,homepath+'APNS.SCH');
 reset(schedfile);
 if ioresult<>0 then begin
  rewrite(schedfile);
  reset(schedfile);
 end;
 last:=filesize(schedfile);
 smchoice:=1;
 repeat
  menuname:=omname+' \ SCHEDULER';
  status;
  option[0]:='Scheduler';
  option[1]:='Add Event';
  option[2]:='Delete Event';
  option[3]:='Edit Event';
  option[4]:='Sort Events';
  ophelp[1]:='Add a new event to the current schedule';
  ophelp[2]:='Delete an event from the schedule list';
  ophelp[3]:='Edit or view a defined schedule event';
  ophelp[4]:='Sort event order by priorities';
  menu(smchoice,4,0);
  case smchoice of
   1:addevent;
   2:if last>0 then delevent else beep;
   3:if last>0 then begin
      picked:=pickevent('Edit');
      if picked>=0 then editevent('Edit an Event',picked);
     end else beep;
   4:sortem;
   else;
  end;
 until smchoice=0;
end;

{***************************************************************************}

begin
 menuname:='';
 helpline:='';
 mode:=lastmode;
 if mode=MONO then dosptr:=ptr($B000,0) else dosptr:=ptr($B800,0);
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

 writeln(#10'Retrieving configuration...');
 assign(setupfile,cfgname);
 reset(setupfile);
 read(setupfile,setup);
 close(setupfile);
 ioerror:=ioresult;
 if ioerror<>0 then begin
  writeln('IO Error ',ioerror,' while reading configuration file');
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
 for loop:=0 to max_menu_items do option[loop]:='';
 save:=dosptr^;

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
 window(1,2,80,24);
 clrscr;
 copyright;

 thatsallfolks:=false;
 cursor:=true;
 status;

 writeln(logfile);
 writeln(logfile,stringof('Í',79));
 writeln(logfile);
 writeln(logfile,'  APCONFIG started at '+time+' on the '+date);

 mmchoice:=1;
 repeat
  menuname:='APCONFIG';
  status;
  option[0]:='Main Menu';
  option[1]:='Configuration';
  option[2]:='Node List';
  option[3]:='Scheduler';
  ophelp[1]:='Configuration sub-menus';
  ophelp[2]:='Node-list management menus';
  ophelp[3]:='Event schedule management menu';
  menu(mmchoice,3,0);
  case mmchoice of
   1:setupmenu;
   2:dialdir;
   3:schedmenu;
   else;
  end;
 until mmchoice=0;
end. {APCONFIG}
