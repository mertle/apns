{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}

program Aurora;

{DEFINE debug}
{DEFINE small}

uses
 crt,dos,comms,sound,printer;

{$I english.inc}

const
 noxmodem:string[46]='No carrier or direct connection flag not set'+cr+lf;

{$I lastrev.inc}

{$I crc16.inc}

{$I aurdefs.inc}

type
 screen=array [1..3840] of byte;
 menurec=array [0..20] of string[60];
 extprot=record
          menuname:string[60];
          upload,
          download:string[80];
         end;
 checkconf=array [1..sizeof(config)] of byte;

 emulation=record
            start,up,down,right,left,home,ennd,insert,f1,f2,f3,f4,f5,f6,f7,
             f8,f9,f10:string[3];
            x,y:byte;
           end;

const
 em_names:array [ansi..teletype] of string[8]=('ANSI-BBS','AVATAR  ','TELETYPE');

var
 security:checkconf absolute setup;
 crc:word;
 checksum:byte;
 dosptr:^screen;                 {screen memory pointer for windows}
 exitsave:pointer;               {points to termination routine}

 em:emulation;                   {handles emulation}
 emulate:procedure;
 current_em:emtype;

 thatsallfolks:boolean;          {time for bed?}
 gosetup:boolean;

 setupfile:file of config;       {disk file for setup}

 capturing:boolean;              {disk capturing flag}
 capfile:text;                   {disk capturing file}
 capname:string[128];            {name of file to capture to}
 cfgname:string[128];
 parameter:string[128];
 username:string[40];
 logfile:text;
 printing:boolean;               {printer capturing flag}
 echo:boolean;                   {local echo flag}
 addlf:boolean;                  {add line feeds to each cr}
 cursor:boolean;                 {holds current cursor state}
 lights:boolean;                 {normal status or modem lights}
 sending:boolean;

 c:char;
 reg:registers;                  {global variables}
 s,laststr:string;
 statusline,timer:string[80];
 time,date:string[10];
 thruput:string[7];
 lenlaststr:byte absolute laststr;
 hour,min,sec:word;
 loop:word;
 ocd:boolean;
 oldcolour:byte;
 mode:byte;

 homepath,                       {where .EXT .PRO .CAP files are}
 curpath,                        {directory for upload download etc}
 oldpath,
 curfile:string[60];
 curport:string[1];
 password:string[40];
 curspeed:string[6];             {global %parameters}

 dir:dirstr;
 name:namestr;                   {fsplit of invoked name}
 ext:extstr;

 option:menurec;                 {used by menu procedure}
 cursor_spec:word;
 ioerror:integer;

 oldx,oldy:byte;                 {window stuff}
 wmin,wmax:word;

{$IFDEF small}

 save   :screen absolute $B900:0;
 store  :screen absolute $BA00:0;
 scratch:screen absolute $BB00:0;

{$ELSE}

 save,store,scratch:screen;

{$ENDIF}

 cfgfile:file of config;
 prot:array [1..18] of extprot;
 noprots:byte;

{**************************************************************************}

function itos(i:word;n:byte):string;

var
 temp:string;
 loop:byte;

begin
 str(i:n,temp);
 for loop:=1 to length(temp) do if temp[loop]=space then temp[loop]:='0';
 itos:=temp;
end;

{**************************************************************************}

procedure beep;

begin
 if setup.sound then play(setup.beep);
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

{*************************************************************************}

procedure em_teletype;

begin
 {Nothing gets translated in teletype mode}
end;

{**************************************************************************}

procedure em_avatar;

var
 c:char;
 x,y,nx,ny:byte;
 wmin,wmax:word;

begin
 x:=wherex;
 y:=wherey;
 c:=auxtc(1000);
 case c of
  ^A:textattr:=auxtb(1000);
  ^B:textattr:=textattr or 128;
  ^C:if y>1 then gotoxy(x,pred(y));
  ^D:if y<24 then gotoxy(x,succ(y));
  ^E:if x>1 then gotoxy(pred(x),y);
  ^F:if x<80 then gotoxy(succ(x),y);
  ^G:clreol;
  ^H:begin
      y:=auxtb(1000);
      gotoxy(auxtb(1000),y);
     end;
  ^L:begin
      textattr:=auxtb(1000);
      ny:=pred(auxtb(1000));
      nx:=pred(auxtb(1000));
      wmin:=windmin;
      wmax:=windmax;
      window(x,y,x+nx,y+ny);
      clrscr;
      windmin:=wmin;
      windmax:=wmax;
     end;
  ^J:begin
      reg.ah:=6;
      reg.bh:=textattr;
      reg.al:=auxtb(1000);
      reg.ch:=pred(auxtb(1000));
      reg.cl:=pred(auxtb(1000));
      reg.dh:=pred(auxtb(1000));
      reg.dl:=pred(auxtb(1000));
      intr($10,reg);
     end;
  ^K:begin
      reg.ah:=7;
      reg.bh:=textattr;
      reg.al:=auxtb(1000);
      reg.ch:=pred(auxtb(1000));
      reg.cl:=pred(auxtb(1000));
      reg.dh:=pred(auxtb(1000));
      reg.dl:=pred(auxtb(1000));
      intr($10,reg);
     end;
  else writeln(logfile,'? Unknown Avatar ^'+(chr(ord(c)+64)));
 end;
end;

{**************************************************************************}

function getparm(var s:string;var l:byte;default:byte):byte;

var
 loop,t:byte;
 s2:string;
 code:integer;

begin
 loop:=1;
 s2:='';
 while (s[loop]<>';') and (loop<l) do inc(loop);
 dec(loop);
 if loop<1 then t:=default else val(copy(s,1,loop),t,code);
 delete(s,1,succ(loop));
 l:=length(s);
 getparm:=t;
end;

{**************************************************************************}

procedure em_ansi;

{Emulates full ANSI-BBS (VT-100) standard, complete with Ansi-sound,
 which is compatable with Basic's PLAY command}

var
 job:char;
 l,x,y:byte;
 s,s1:string;
 c:char;

begin
 s:='';
 c:=auxtc(1000);             {'[' or 'O' if VT-100}
 c:=upcase(auxtc(1000));     {first char in esc sequence}
 if c='M' then begin
  repeat
   c:=upcase(auxtc(1000));
   if (c>#32) and (not timedout) then s:=s+c;
  until (c<#33) or timedout;
  if s[1]='B' then delete(s,1,1);
  if setup.sound then play(s);
 end else begin
  s:=c;                     {remember to add first char!}

  while not (timedout or (c in ['A'..'Z'])) do begin
   c:=upcase(auxtc(1000));
   s:=s+c;
  end;
  if not (c in ['A'..'Z']) then exit;
  s1:=s;
  l:=length(s);
  job:=upcase(s[l]);
  s[l]:=';';
  case job of
   'X':window(1,getparm(s,l,1),80,24);
   'K':clreol;
   'J':clrscr;
   'A':begin
        y:=wherey-getparm(s,l,1);
        if y<1 then y:=1;
        gotoxy(wherex,y);
       end;
   'B':begin
        y:=wherey+getparm(s,l,1);
        if y>24 then y:=24;
        gotoxy(wherex,y);
       end;
   'C':begin
        x:=wherex+getparm(s,l,1);
        if x>80 then x:=80;
        gotoxy(x,wherey);
       end;
   'D':begin
        x:=wherex-getparm(s,l,1);
        if x<1 then x:=1;
        gotoxy(x,wherey);
       end;
   'F',
   'H':begin
        y:=getparm(s,l,1);
        gotoxy(getparm(s,l,1),y);
       end;
   'S':begin
        em.x:=wherex;
        em.y:=wherey;
       end;
   'U':gotoxy(em.x,em.y);
   'N':rawsend(esc+'['+chr(wherey)+';'+chr(wherex)+'R');
   'M':repeat
        case getparm(s,l,0) of
         0:textattr:=white;
         1:highvideo;
         2:lowvideo;
         5,
         6:textattr:=textattr+blink;
        30:textcolor(black);
        31:textcolor(lightred);
        32:textcolor(lightgreen);
        33:textcolor(yellow);
        34:textcolor(lightblue);
        35:textcolor(lightmagenta);
        36:textcolor(lightcyan);
        37:textcolor(white);
        40:textbackground(black);
        41:textbackground(red);
        42:textbackground(green);
        43:textbackground(brown);
        44:textbackground(blue);
        45:textbackground(magenta);
        46:textbackground(cyan);
        47:textbackground(lightgray);
        else;
       end;
       until l=0;
   else writeln(logfile,'? Unknown ANSI '+s1);
  end;
 end;
end; {em_ansi}

{**************************************************************************}

procedure em_install(term:emtype);

const
 ansi_em:emulation=(start:esc;up:esc+'[A';down:esc+'[B';right:esc+'[C';
                    left:esc+'[D';home:esc+'[H';ennd:esc+'[K';insert:^V;
                    f1:esc+'[P';f2:esc+'[Q';f3:esc+'[R';f4:esc+'[S');
 avatar_em:emulation=(start:^V;up:nul+#72;down:nul+#80;right:nul+#77;
                      left:nul+#75;home:nul+#71;ennd:nul+#79;insert:nul+#82;
                      f1:#0#59;f2:#0#60;f3:#0#61;f4:#0#62;f5:#0#63;f6:#0#64;
                      f7:#0#65;f8:#0#66;f9:#0#67;f10:#0#68);
 tty_em:emulation=(start:nul;up:^E;down:^X;right:^D;left:^S;home:^Q^S;ennd:^Q^D;
                   insert:^V);


begin
 fillchar(em,sizeof(em),#0);
 em.x:=1;
 em.y:=1;
 case term of
  ansi:begin
        em:=ansi_em;
        @emulate:=@em_ansi;
       end;
  avatar:begin
          @emulate:=@em_avatar;
          em:=avatar_em;
         end;
  teletype:begin
            @emulate:=@em_teletype;
            em:=tty_em;
           end;
  else;
 end;
end;

{**************************************************************************}

procedure swapem(var save:screen);

begin
 scratch:=dosptr^;
 dosptr^:=save;
 save:=scratch;
end;

{**************************************************************************}

function flag(test:boolean;inchar:char):char;

begin
 if test then flag:=upcase(inchar) else flag:=inchar;
end;

{**************************************************************************}

function getstatus:string;

const
 parities:array[no_par..sp_par] of char=('N','E','O','M','S');
 starthour:shortint=-1;
 startmin:shortint=-1;
 startsec:shortint=-1;
 secon:shortint=0;
 minon:shortint=0;
 houron:shortint=0;

var
 hun,year,month,day,dow:word;
 s1,s2,s3,s4,s5,s6:string[6];
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
 str(setup.baud:6,s1);
 str(setup.length,s2);
 str(setup.stopbits,s3);

 s4:=itos(houron,2);
 s5:=itos(minon,2);
 s6:=itos(secon,2);

 if carrierdetect then
  timer:='њ Elapsed time online '+s4+' hours '+s5+' minutes '+s6+' seconds';
 temp:=space+em_names[current_em]+' і '+s1+' і '+
       s2+'щ'+parities[setup.parity]+'щ'+s3+' і ';
 if lights then begin
  if carrierdetect then temp:=temp+'DCD.' else temp:=temp+'dcd.';
  if charwaiting then temp:=temp+'RX.' else temp:=temp+'rx.';
  if sending then temp:=temp+'TX.' else temp:=temp+'tx.';
  if port[portbase+MSR] and CTS=CTS then temp:=temp+'CTS.' else
   temp:=temp+'cts.';
  if port[portbase+MCR] and RTS=RTS then temp:=temp+'RTS' else
   temp:=temp+'rts';
 end else temp:=temp+
  flag(carrierdetect,'o')+'щ'+
  flag(direct,'d')+'щ'+
  flag(capturing,'c')+'щ'+
  flag(printing,'p')+'щ'+
  flag(echo,'e')+'щ'+
  flag(addlf,'a')+'щ'+
  flag(setup.sound,'s')+'щ'+
  flag(not setup.direct,'b')+'щ'+
  flag(setup.snow,'w');
 temp:=temp+' і '+s4+':'+s5+':'+s6+' і '+time+' '+date;
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

procedure log(s:string);

begin
 writeln(s);
 writeln(logfile,s);
end;

{**************************************************************************}

{$F+}procedure exitroutine;{$F-}

begin
 if running then closecomms;
 window(1,1,80,25);
 normvideo;
 clrscr;
 cursoron;
 if erroraddr=nil then writeln('Thanks for using Aurora.') else begin
  str(exitcode,s);
  log('! Abnormal program termination. Please report code '+s);
  writeln;
 end;
 s:=getstatus;
 writeln(logfile,#13#10'  Aurora exited at '+time+' on the '+date);
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
  s:=itos(outer,2);
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

{$I xmodem.inc}

{**************************************************************************}

procedure receive;

const
 lastcap:char=#0;

var
 c:string[2];
 a:char;
 b,d:byte;
 s:string;

begin
 s:='';
 status;
 cursoroff;
 c:=chr(getaux);
 if (c=#27) and (current_em=avatar) and (setup.ansiavatar) then em_ansi else
 if c=em.start then emulate else case c[1] of
  BS : s:=bs+space+bs;
  TAB: begin
        b:=9-(wherex mod 8);
        s:=stringof(space,b);
       end;
  ^L : clrscr;
  ^Y : if current_em=avatar then begin
        s:=stringof(auxtc(1000),auxtb(1000));
       end;
  BEL: beep;
  else if not ((c=cr) and (lastcap=cr)) then begin
   if addlf and (c=cr) then c:=c+lf;
   write(c);
   if lenlaststr>253 then delete(laststr,1,2);
   laststr:=laststr+c;
   laststr[lenlaststr]:=upcase(laststr[lenlaststr]);
   if capturing then write(capfile,c);
   if printing then write(lst,c);
  end;
 end;
 lastcap:=c[1];
 if s<>'' then begin
  write(s);
  if capturing then write(capfile,s);
 end;
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
 window(left,up,right,down);
 clrscr;
 windmin:=wmin;
 windmax:=wmax;
 box:=frame[setup.winstyle];
 if border then begin
  gotoxy(pred(left),pred(up));
  writeln(box[1],stringof(box[2],succ(right-left)),box[3]);
  if title<>'' then begin

   gotoxy(left+((right-left)-(length(title)+4)) shr 1,pred(up));

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
 window(left,up,right,down);
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
 wmin,wmax:word;
 oc,x,y:byte;

begin
 stopnow:=false;
 assign(f,homepath+'AURORA.HLP');
 reset(f);
 if ioresult=0 then begin
  repeat
   readln(f,s);
  until (pos('.'+title,s)>0) or seekeof(f);
  if not(eof(f)) then begin
   oc:=oldcolour;
   x:=wherex;
   y:=wherey;
   wmin:=windmin;
   wmax:=windmax;
   window(1,1,80,25);
   openwin(3,2,78,23,save,oldx,oldy,true,title+' Help');
   repeat
    readln(f,s);
    if s='.more' then begin
     centre('* Press any key for more *');
     repeat status until keypressed;
     if readkey=ESC then stopnow:=true;
     clrscr;
    end else if s<>'.' then writeln(space,s);
   until (eof(f)) or (s='.') or (stopnow);
   close(f);
   if not stopnow then begin
    repeat status until keypressed;
    while keypressed do c:=readkey;
   end;
   closewin(save,oldx,oldy);
   windmin:=wmin;
   windmax:=wmax;
   oldcolour:=oc;
   gotoxy(x,y);
  end;
 end;
end;

{**************************************************************************}

procedure menu(var default:byte;max:byte;getout:byte);

var
 loop,x,y,oldef,oldval,width,start:byte;
 c:char;
 endnow:boolean;
 s,hotkey:string[20];

begin
 cursoroff;
 oldval:=default;
 endnow:=false;
 width:=0;
 for loop:=0 to max do
  if length(option[loop])>width then width:=length(option[loop]);
 inc(width);
 start:=(80-width) shr 1;
 openwin(start,2,start+width,max+3,store,x,y,true,option[0]);
 for loop:=1 to max do begin
  gotoxy(2,succ(loop));
  textcolor(setup.wsclr);
  write(option[loop][1]);
  textcolor(setup.wfclr);
  writeln(copy(option[loop],2,pred(length(option[loop]))));
 end;
 hotkey[0]:=#20;
 for loop:=1 to max do if option[loop]<>'' then hotkey[loop]:=upcase(option[loop][1])
                                           else hotkey[loop]:='ю';
 for loop:=succ(max) to 20 do hotkey[loop]:='ю';
 repeat
  gotoxy(1,succ(default));
  textcolor(setup.hfclr);
  textbackground(setup.hbclr);
  clreol;
  write(space,option[default]);
  textcolor(setup.wfclr);
  textbackground(setup.wbclr);

  oldef:=default;
  repeat status until keypressed;
  c:=upcase(readkey);
  if c=cr then endnow:=true;
  if c=esc then begin
   endnow:=true;
   default:=getout;
  end;
  s:=hotkey;
  for loop:=1 to default do s[loop]:='ю';
  if pos(c,s)>0 then default:=pos(c,s);
  if (default=oldef) and (pos(c,hotkey)>0) then default:=pos(c,hotkey);
  if c=nul then case readkey of
   #72:dec(default);
   #80:inc(default);
   #71:default:=1;
   #79:default:=max;
   #24:begin
        swapem(save);
        repeat status until keypressed;
        while keypressed do c:=readkey;
        swapem(save);
       end;
   #44:onlinehelp(option[0]);
   else;
  end;
  if not endnow then begin
   if default<1 then default:=max else
   if default>max then default:=1;
   if oldef<>default then begin
    gotoxy(1,succ(oldef));
    clreol;
    textcolor(setup.wsclr);
    write(' ',option[oldef][1]);
    textcolor(setup.wfclr);
    write(copy(option[oldef],2,pred(length(option[oldef]))));
   end;
  end;
 until endnow;
 closewin(store,x,y);
 cursoron;
end;

{**************************************************************************}

procedure getstring(var s:string;max:byte;title:string);

var
 oldx,oldy,x,y,edge:byte;
 len:byte absolute s;
 old:string;
 c:char;
 fkey:boolean;

begin
 edge:=(76-max) shr 1;
 if max<length(title) then edge:=(70-length(title)) shr 1;
 openwin(2+edge,9,78-edge,11,store,oldx,oldy,true,title);
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
    #44:onlinehelp(title);
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
 until pos(c,#27#13)>0;
 if c=#27 then s:=old;
 closewin(store,oldx,oldy);
end;

{**************************************************************************}

procedure errors;

var
 s:string[20];

begin
 write(cr+lf+'The program terminated with error-level ',dosexitcode,
             ', DOS reports ');
 case doserror of
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
 writeln(s);
end;

{**************************************************************************}

procedure replace(var s:string;orig,rep:string;once:boolean);

var
 temp:byte;
 us:string;

begin
 repeat
  us:=ucase(s);
  temp:=pos(orig,us);
  if temp>0 then begin
   delete(s,temp,length(orig));
   insert(rep,s,temp);
  end;
 until (temp=0) or once;
end;

{**************************************************************************}

procedure opencap;

begin
 assign(capfile,capname);
 if exist(capname) then append(capfile) else rewrite(capfile);
 capturing:=true;
 writeln(logfile,'  Commenced capturing at '+time+' on the '+date);
end;

{**************************************************************************}

procedure closecap;

begin
 writeln(logfile,'  Finished capturing at '+time+' on the '+date);
 close(capfile);
 capturing:=false;
end;

{**************************************************************************}

procedure pathsearch(match:string;var s:string;var ext:extstr);

var
 search:string[128];

begin
 if not(exist(match)) then begin
  search:=fsearch(match,homepath+';'+getenv('PATH'));
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
 replace(tail,'%FILE','ю',false);
 while pos('ю',tail)>0 do begin
  getstring(curfile,60,'File Specifier');
  replace(tail,'ю',curfile,true);
 end;
 replace(tail,'  ',' ',false);
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
 openwin(1,1,80,25,save,oldx,oldy,false,'');
 log('  Executing '+command+space+tail);
 oldcap:=capturing;
 if capturing then closecap;
 exec(command,tail);
 reg.ah:=$0F;
 intr($10,reg);
 if reg.al<>mode then begin
  reg.ax:=mode;
  intr($10,reg);
 end;
 if oldcap then opencap;
 errors;
 anykey(9,false);
 closewin(save,oldx,oldy);
end;

{**************************************************************************}

procedure initialise;

var
 loop:byte;

begin
 with setup do setport(comport,baud,parity,length,stopbits);
 opencomms;
 if setup.cmdinit<>'' then begin
  openwin(18,16,62,22,save,oldx,oldy,true,'Initialising Modem');
  sending:=true;
  status;
  auxwrite(setup.cmdinit);
  sending:=false;
  status;
  delay(20);
  while charwaiting do begin
   status;
   receive;
   delay(20);
  end;
  closewin(save,oldx,oldy);
 end;
end;

{**************************************************************************}

procedure copyright;

begin
 writeln(
  cr+lf+' ЬЫЫЫЬ'
 +cr+lf+'ЫЫЫЯЫЫЫ'
 +cr+lf+'ЫЫ   ЫЫ ЫЫ   ЫЫ ЫЫЬЫЫЫ ЬЫЫЫЫЫЬ ЫЫЬЫЫЫ ЫЫЫЫЫЬ    Complete Communications'
 +cr+lf+'ЫЫ   ЫЫ ЫЫ   ЫЫ ЫЫЫЯ   ЫЫ   ЫЫ ЫЫЫЯ       ЫЫ            Software'
 +cr+lf+'ЫЫЫЫЫЫЫ ЫЫ   ЫЫ ЫЫ     ЫЫ   ЫЫ ЫЫ    ЬЫЫЫЫЫЫ',
  cr+lf+'ЫЫ   ЫЫ ЫЫ   ЫЫ ЫЫ     ЫЫ   ЫЫ ЫЫ    ЫЫ   ЫЫ     Designed and Coded by'
 +cr+lf+'ЫЫ   ЫЫ ЯЫЫЫЫЫЫ ЫЫ     ЯЫЫЫЫЫЯ ЫЫ    ЯЫЫЫЫЫЫ      Michael E. Ralphson'
 +lf
 +cr+lf+'Version '+version+' (Last Revision '+lastrev+')',
  cr+lf+'Copyright (c) 1989 - 1991 Michael E. Ralphson, All Rights Reserved');
end;

{**************************************************************************}

procedure hangup(ask:boolean);

var
 b:byte;

begin
 openwin(20,5,60,8,save,oldx,oldy,true,'Hang Up');
 if ask then begin
  centre(lf+'Hang-up the connection? y/N');
  repeat status until keypressed;
  c:=upcase(readkey);
  writeln;
 end else c:='Y';
 if c='Y' then begin
  centre(lf+'Hanging up...');
  lowerdtr;
  delay(250);
  raisedtr;
  if carrierdetect then auxwrite(setup.cmdhangup)
                   else sendaux(13);
  delay(100);
  while charwaiting do begin
   b:=getaux;
   delay(10);
  end;
  writeln;
  if carrierdetect and not direct then begin
   centre(lf+'Hangup Failed'+cr+lf);
   anykey(1,true);
  end;
 end;
 closewin(save,oldx,oldy);
end;

{**************************************************************************}

procedure help;

begin
 cursoroff;
 openwin(13,2,67,19,save,oldx,oldy,true,'Aurora Help');
 writeln(#10' ALT-A  Ascii upload        ALT-B  Bypass EMSI mailer');
 writeln(' ALT-C  Clear screen        ALT-D  Dialling directory');
 writeln(' ALT-E  Extended help       ALT-F  Flags display');
 writeln(' ALT-G                      ALT-H  Hang-up');
 writeln(' ALT-I  Initialise modem    ALT-J');
 writeln(' ALT-K                      ALT-L  Log toggle on/off');
 writeln(' ALT-M  Modem lights on/off ALT-N  Quick name');
 writeln(' ALT-O  Old screen          ALT-P  Printer on/off');
 writeln(' ALT-Q  Quick password      ALT-R  Run script');
 writeln(' ALT-S  Setup menu          ALT-T  Talk (chat) mode');
 writeln(' ALT-U  Utilities menu      ALT-V');
 writeln(' ALT-W                      ALT-X  Exit');
 writeln(' ALT-Y                      ALT-Z  Help'#10);
 writeln(' PG-UP  Upload file(s)');
 writeln(' PG-DN  Download file(s)');
 repeat status until keypressed;
 cursoron;
 closewin(save,oldx,oldy);
end;

{**************************************************************************}

procedure yesno(s:string;b:boolean);

begin
 write(space,s[1],' .. ',s);
 if b then writeln(' (Yes)') else writeln(' (No)');
end;

{**************************************************************************}

procedure flags;

var
 c:char;

begin
 cursoroff;
 openwin(26,2,55,12,save,oldx,oldy,true,'Flags');
 writeln;
 yesno('Online',carrierdetect);
 yesno('Direct connection',direct);
 yesno('Capturing',capturing);
 yesno('Printing',printing);
 yesno('Echo local',echo);
 yesno('Add line-feeds',addlf);
 yesno('Sound',setup.sound);
 yesno('Bios writes',not setup.direct);
 yesno('Wait for snow',setup.snow);
 repeat status until keypressed;
 c:=readkey;
 cursoron;
 closewin(save,oldx,oldy);
end;

{**************************************************************************}

function get(var f:text;var s:string):boolean;

var
 temp:boolean;

begin
 repeat
  readln(f,s);
  temp:=((s<>'') and (s[1]<>';'))
 until temp or seekeof(f);
 get:=temp;
end;

{**************************************************************************}

procedure extsetup;

var
 s:string[128];
 f:text;
 test:boolean;

begin
 s:=homepath+'AURORA.PRO';
 noprots:=0;
 if exist(s) then begin
  assign(f,s);
  reset(f);
  repeat
   inc(noprots);
   test:=get(f,prot[noprots].menuname);
   test:=get(f,prot[noprots].upload);
   test:=get(f,prot[noprots].download);
  until seekeof(f) or (noprots=18);
  if not test then dec(noprots);
  close(f);
 end;
end;

{**************************************************************************}

procedure utilmenu;

var
 umchoice:byte;
 s:string[128];
 loop:byte;
 f:text;
 test:boolean;

begin
 s:=homepath+'AURORA.EXT';
 noprots:=0;
 if exist(s) then begin
  assign(f,s);
  reset(f);
  repeat
   inc(noprots);
   test:=get(f,prot[noprots].menuname);
   test:=get(f,prot[noprots].upload);
  until seekeof(f) or (noprots=18);
  if not test then dec(noprots);
  close(f);
 end;
 umchoice:=1;
 repeat
  option[0]:='Utilities';
  option[1]:='DOS Shell';
  option[2]:='DOS Command';
  for loop:=3 to noprots+2 do option[loop]:=prot[loop-2].menuname;
  menu(umchoice,noprots+2,0);
  case umchoice of
   0:;
   1:run('');
   2:begin
      openwin(2,5,78,7,save,oldx,oldy,true,'Dos Command');
      getdir(0,curpath);
      write(cr+lf+space,curpath,'>');
      readln(s);
      closewin(save,oldx,oldy);
      if s<>'' then run(s);
     end;
   else run(prot[umchoice-2].upload);
  end;
 until umchoice=0;
end;

{**************************************************************************}

{$I setup.inc}

{**************************************************************************}

procedure winmsg(s1,s2:string);

begin
 openwin(18,11,62,15,save,oldx,oldy,true,s1);
 writeln;
 centre(s2);
 writeln;
 anykey(9,true);
 closewin(save,oldx,oldy);
end;

{**************************************************************************}

procedure ascii_upload;

var
 f:text;
 s:string;
 loop:byte;

begin
 s:='';
 getstring(s,60,'Ascii Upload Filename');
 if exist(s) then begin
  assign(f,s);
  reset(f);
  repeat
   readln(f,s);
   if s='' then s:=space;
   sending:=true;
   for loop:=1 to length(s) do begin
    rawsend(s[loop]);
    status;
    if echo then write(s[loop]);
    delay(10);
    if keypressed and (readkey=#27) then begin
     close(f);
     winmsg('Abort','Ascii upload aborted');
     exit;
    end;
    while charwaiting do receive;
   end;
   sending:=false;
   status;
   sendaux(13);
   if echo then write(#13);
   if echo and addlf then write(#10);
   delay(10);
   while charwaiting do receive;
  until eof(f);
  close(f);
 end;
end;

{**************************************************************************}

procedure upload;

var
 temp,upldchoice:byte;
 size:word;
 oldcap,result:boolean;
 f,title:string[128];
 bytestran:longint;

begin
 extsetup;
 getdir(0,oldpath);
 chdir(setup.updir);
 if ioresult<>0 then chdir(oldpath);
 upldchoice:=1;
 option[0]:='Upload';
 option[1]:='Xmodem (CRC)';
 option[2]:='Xmodem (1k)';
 if noprots>0 then for temp:=1 to noprots do
  option[temp+2]:=prot[temp].menuname;
 menu(upldchoice,noprots+2,0);
 case upldchoice of
  0:;
  1,
  2:begin
     title:='Xmodem (Checksum, CRC';
     if upldchoice=1 then size:=128 else begin
      title:=title+', 1k';
      size:=1024;
     end;
     openwin(2,7,79,12,save,oldx,oldy,true,title+') Upload');
     writeln;
     if carrierdetect then begin
      window(1,1,80,24);
      f:='';
      temp:=oldcolour;
      getstring(f,60,'Upload Filename');
      oldcolour:=temp;
      window(2,7,79,12);
      if f<>'' then
       if exist(f) then begin
        oldcap:=capturing;
        if capturing then closecap;
        result:=x_upload(f,size,bytestran);
        log('  Uploaded '+f+', throughput '+thruput);
        if oldcap then opencap;
       end else writeln(lf+'File not found.');
     end else centre(noxmodem);
     anykey(9,false);
     closewin(save,oldx,oldy);
    end;
  else run(prot[upldchoice-2].upload);
 end;
 chdir(oldpath);
end;

{**************************************************************************}

procedure download;

var
 dnldchoice,temp:byte;
 oldcap,result:boolean;
 f:string[128];
 bytestran:longint;

begin
 extsetup;
 getdir(0,oldpath);
 chdir(setup.downdir);
 if ioresult<>0 then chdir(oldpath);
 dnldchoice:=1;
 option[0]:='Download';
 option[1]:='Xmodem (CRC)';
 option[2]:='Xmodem (1k)';
 if noprots>0 then for temp:=1 to noprots do
  option[temp+2]:=prot[temp].menuname;
 menu(dnldchoice,noprots+2,0);
 case dnldchoice of
  0:;
  1,
  2:begin
     openwin(2,7,79,12,save,oldx,oldy,true,'Xmodem (Checksum, CRC, 1k) Download');
     writeln;
     if carrierdetect then begin
      f:='';
      temp:=oldcolour;
      window(1,1,80,24);
      getstring(f,60,'Download Filename');
      window(2,7,79,12);
      oldcolour:=temp;
      if f<>'' then begin
       oldcap:=capturing;
       if capturing then closecap;
       result:=x_download(f,bytestran);
       log('  Downloaded '+f+', throughput '+thruput);
       if oldcap then opencap;
      end;
     end else centre(noxmodem);
     anykey(9,false);
     closewin(save,oldx,oldy);
    end;
  else run(prot[dnldchoice-2].download);
 end;
 chdir(oldpath);
end;

{**************************************************************************}

procedure script(s:string);

var
 f:text;
 loop,number:byte;
 temp,new,verb:string[128];
 size,psn,oldpsn,limit:word;
 code:integer;
 thour,tmin,tsec:word;
 exitnow,result:boolean;
 bytestran:longint;

begin
 extsetup;
 size:=128;
 exitnow:=false;
 assign(f,s);
 reset(f);
 repeat
  if get(f,s) then begin
   while s[1]=' ' do delete(s,1,1);
   s:=ucase(s);
   verb:='';
   loop:=1;
   while (s[loop]<>' ') and (loop<=length(s)) do begin
    verb:=verb+s[loop];
    inc(loop);
   end;
   delete(s,1,loop);
   if verb='AWAIT' then begin
    temp:='';
    loop:=1;
    while (s[loop]<>' ') and (loop<length(s)) do begin
     temp:=temp+s[loop];
     inc(loop);
    end;
    val(temp,limit,code);
    delete(s,1,loop);
    oldpsn:=0;
    psn:=pos('^',s);
    while psn>oldpsn do begin    { Control character }
     psn:=pos('^',s);
     if length(s)>=succ(psn) then begin
      s[succ(psn)]:=chr(ord(s[succ(psn)])-64);
      delete(s,psn,1);
     end;
     oldpsn:=psn;
     psn:=pos('^',s);
    end;
    replace(s,'|',cr,false);
    status;
    thour:=hour;
    tmin:=min;
    tsec:=sec+limit;
    if tsec>59 then begin
     inc(tmin);
     dec(tsec,60);
    end;
    if tmin>59 then begin
     inc(thour);
     dec(tmin,60);
    end;
    if thour>23 then thour:=0;
    if limit=0 then thour:=25;
    repeat
     status;
     if charwaiting then receive;
     exitnow:=keypressed and (readkey=ESC);
    until exitnow or (pos(s,laststr)>0) or ((hour=thour) and (min=tmin) and (sec=tsec));
    if pos(s,laststr)=0 then begin
     winmsg('Abort','Script processing aborted');
     close(f);
     exit;
    end else laststr:='';
   end;
   if verb='CLEAR' then clrscr;
   if verb='WRITE' then writeln(s);
   if verb='SEND' then begin
    replace(s,'%PASSWORD',password,false);
    replace(s,'%USERNAME',username,false);
    auxwrite(s);
   end;
   if verb='DOS' then run(s);
   if verb='PLAY' then play(s);
   if (verb='STAMP') then begin
    status;
    log('  '+date+space+time+space+s);
   end;
   if (verb='CAPON') and (not capturing) then opencap;
   if (verb='CAPOFF') and capturing then closecap;
   if verb='END' then exitnow:=true;
   if verb='UPLOAD' then begin
    getdir(0,oldpath);
    chdir(setup.updir);
    if ioresult<>0 then chdir(oldpath);
    temp:='';
    loop:=1;
    repeat
     temp:=temp+s[loop];
     inc(loop);
    until (s[loop]=' ') or (loop>length(s));
    delete(s,1,loop);
    val(temp,number,code);
    if number=2 then begin
     size:=1024;
     number:=1;
    end;
    if (number=1) and (exist(s)) then begin
     openwin(2,7,79,12,save,oldx,oldy,true,'Xmodem (Checksum, CRC) Upload');
     result:=x_upload(s,size,bytestran);
     log('  Uploaded '+s+', throughput '+thruput);
     closewin(save,oldx,oldy);
    end;

    if number in [3..noprots+2] then begin
     temp:=prot[number-2].upload;
     replace(temp,'%FILE',s,false);
     run(temp);
    end;
    chdir(oldpath);
   end;
   if verb='DOWNLOAD' then begin
    getdir(0,oldpath);
    chdir(setup.downdir);
    if ioresult<>0 then chdir(oldpath);
    temp:='';
    loop:=1;
    repeat
     temp:=temp+s[loop];
     inc(loop);
    until (s[loop]=' ') or (loop>length(s));
    delete(s,1,loop);
    val(temp,number,code);
    if (number=1) or (number=2) then begin
     openwin(2,7,79,12,save,oldx,oldy,true,'Xmodem (Checksum, CRC, 1k) Download');
     result:=x_download(s,bytestran);
     log('  Downloaded '+s+', throughput '+thruput);
     closewin(save,oldx,oldy);
    end;
    if number in [3..noprots+2] then begin
     temp:=prot[number-2].download;
     replace(temp,'%FILE',s,false);
     run(temp);
    end;
    chdir(oldpath);
   end;
   if verb='EXIT' then begin
    close(f);
    if capturing then closecap;
    if carrierdetect then hangup(false);
    thatsallfolks:=true;
    exit;
   end;
   if verb='IF' then if pos(s,laststr)=0 then result:=get(f,temp) else laststr:='';
   if verb='GOTO' then begin
    reset(f);
    repeat
     result:=get(f,new);
     loop:=1;
     temp:='';
     while (new[loop]<>' ') and (loop<=length(s)) do begin
      temp:=temp+new[loop];
      inc(loop);
     end;
    until (temp=s) or seekeof(f);
   end;
  while charwaiting do receive;
  status;
  if keypressed and (readkey=ESC) then begin
   close(f);
   winmsg('Abort','Script processing aborted');
   exit;
  end;
 end;
 until seekeof(f) or exitnow;
 close(f);
end;

{**************************************************************************}

procedure chat;

var
 c:char;

begin
 openwin(3,2,78,23,save,oldx,oldy,true,'Chat Mode');
 centre(#10'Pressing ESC from either machine exits chat mode'#10);
 writeln;
 repeat
  status;
  c:=#0;
  while charwaiting do begin
   textcolor(yellow);
   c:=chr(getaux);
   write(c);
  end;
  if keypressed then begin
   textcolor(white);
   c:=readkey;
   sendaux(ord(c));
   write(c);
  end;
  if c=#13 then write(#10);
  if c=#8 then write(space+#8);
 until c=ESC;
 closewin(save,oldx,oldy);
end;

{**************************************************************************}

{$I dialdir.inc}

{**************************************************************************}

procedure extendedhelp;

var
 ehchoice:byte;

begin
 ehchoice:=1;
 repeat
  option[0]:='Extended Help';
  option[1]:='Aurora Key Commands';
  option[2]:='Aurora Status Flags';
  option[3]:='Aurora General';
  menu(ehchoice,3,0);
  case ehchoice of
   0:;
   1:begin
      help;
      c:=readkey;
     end;
   2:flags;
   else onlinehelp(option[ehchoice]);
  end;
 until ehchoice=0;
end;

{**************************************************************************}

procedure quit;

var
 c:char;
 prompt,keys:string[80];

begin
 prompt:='Exit to DOS';
 keys:='y';
 openwin(10,5,70,7,save,oldx,oldy,true,'Exit Aurora');
 if capturing then begin
  prompt:=prompt+', Capture off';
  keys:=keys+'/c';
 end;
 if carrierdetect then begin
  prompt:=prompt+', Hang-up';
  keys:=keys+'/h';
 end;
 centre(lf+prompt+', Return ('+keys+'/R) ?');
 c:=upcase(readkey);
 closewin(save,oldx,oldy);
 case c of
  'C':if capturing then closecap;
  'H':if carrierdetect then hangup(false);
  'Y':begin
       if capturing then closecap;
       if carrierdetect then hangup(false);
       closecomms;
       thatsallfolks:=true;
      end;
  else;
 end;
end;

{**************************************************************************}

procedure checkkeyboard;

var
 inkey:char;
 altkey:byte;
 s:string[60];

begin
 inkey:=readkey;
 case inkey of
  nul:begin

   altkey:=ord(readkey);
   case altkey of

    71:rawsend(em.home); {terminal translations}
    72:rawsend(em.up);
    75:rawsend(em.left);
    77:rawsend(em.right);
    79:rawsend(em.ennd);
    80:rawsend(em.down);
    82:rawsend(em.insert);
    83:rawsend(del);
    59:rawsend(em.f1);
    60:rawsend(em.f2);
    61:rawsend(em.f3);
    62:rawsend(em.f4);
    63:rawsend(em.f5);
    64:rawsend(em.f6);
    65:rawsend(em.f7);
    66:rawsend(em.f8);
    67:rawsend(em.f9);
    68:rawsend(em.f10);

{P} 25:printing:=not printing;
{F} 33:flags;
{R} 19:begin
        s:='';
        getstring(s,60,'Script Name');
        fsplit(s,dir,name,ext);
        if dir='' then dir:=homepath;
        if ext='' then ext:='.SCR';
        s:=dir+name+ext;
        if exist(s) then script(s);
       end;
{T} 20:chat;
{B} 48:rawsend('**EMSI_CLIFA8C'#13);
{N} 49:if username<>'' then rawsend(username+CR);
{A} 30:ascii_upload;
{S} 31:setupmenu;
{D} 32:dialdir;
{O} 24:begin
        cursoroff;
        swapem(save);
        repeat status until keypressed;
        while keypressed do c:=readkey;
        swapem(save);
        cursoron;
       end;
{I} 23:initialise;
{U} 22:utilmenu;
    81:download;
    73:upload;
{C} 46:begin
        textcolor(setup.fclr);
        textbackground(setup.bclr);
        clrscr;
        window(1,1,80,24);
       end;
{Z} 44:help;
{M} 50:begin
        lights:=not lights;
        setup.deflights:=lights;
       end;
{Q} 16:if password<>'' then rawsend(password+CR);
{E} 18:extendedhelp;
{X} 45:quit;

{H} 35:hangup(true);
{L} 38:if capturing then closecap else opencap;

{$IFDEF debug}

    else writeln('Unknown ALT-key ',altkey);

{$ELSE}

    else beep;

{$ENDIF}

   end;
  end;
  esc:if carrierdetect then sendaux(27);
  else begin
   sending:=true;
   status;
   rawsend(inkey);
   if echo then write(inkey);
   if echo and addlf and (inkey=#13) then write(lf);
   sending:=false;
  end;
 end;
end;

{**************************************************************************}

{ Aurora }

begin
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

 curfile:='';
 s:=fexpand(paramstr(0));
 fsplit(s,dir,name,ext);
 homepath:=dir;
 capname:=homepath+'AURORA.CAP';
 cfgname:=homepath+'AURORA.CFG';
 s:=homepath+'AURORA.LOG';
 assign(logfile,s);
 if exist(s) then append(logfile) else rewrite(logfile);
 gosetup:=false;
 sending:=false;

 writeln('Retrieving configuration...');
 assign(setupfile,cfgname);
 reset(setupfile);
 read(setupfile,setup);
 close(setupfile);

 ioerror:=ioresult;
 if ioerror<>0 then begin
  str(ioerror,s);
  log('! Error '+s+' reading configuration file');
  gosetup:=true;
 end;

 getdir(0,curpath);

 exitsave:=exitproc;
 exitproc:=@exitroutine;

 {This is the first place the variable SETUP is referenced}

 username:=setup.caller;

 current_em:=setup.emu;
 em_install(current_em);

 directvideo:=setup.direct;
 checksnow:=setup.snow;
 statusline:='';
 fillchar(option,sizeof(option),#0);
 direct:=setup.nulmodem;

 if mode<>CO80 then move(monocols,setup.fclr,7);

 save:=dosptr^;
 textcolor(setup.fclr);
 textbackground(setup.bclr);
 clrscr;
 window(1,1,80,24);
 copyright;
 thatsallfolks:=false;
 capturing:=false;
 printing:=false;
 echo:=setup.defecho;
 addlf:=setup.deflinefeed;
 lights:=setup.deflights;
 laststr:='';
 cursor:=true;

 writeln(cr+lf+'Press ALT-Z for Help, ALT-X to exit'+lf);
 str(setup.baud:6,curspeed);
 str(setup.comport,curport);
 password:='';
 ocd:=false;
 status;

 writeln(logfile);
 writeln(logfile,stringof('Н',79));
 writeln(logfile,#13#10'  Aurora started at '+time+' on the '+date);

 parameter:=ucase(paramstr(1));

 if parameter='SETUP' then begin
  log('  User requested configuration');
  setupmenu;
  exit;
 end;

 if gosetup then setupmenu;

 initialise;

 if parameter='DIAL' then begin
  log('  User requested dialling directory');
  dialdir;
 end;

 repeat
  if charwaiting then receive;
  if keypressed then checkkeyboard else if not charwaiting then begin
   status;
   if (setup.zmodauto) and (pos(zsig,laststr)>0) then begin
    extsetup;
    getdir(0,oldpath);
    chdir(setup.downdir);
    if ioresult<>0 then chdir(oldpath);
    run(prot[1].download);
    chdir(oldpath);
    laststr:='';
   end;
   if (not carrierdetect) and ocd then begin
    textcolor(setup.fclr);
    textbackground(setup.bclr);
    writeln;
    log(timer);
   end;
   ocd:=carrierdetect;
  end;
 until thatsallfolks;
end. {Aurora}
