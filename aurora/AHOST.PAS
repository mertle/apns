{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}
program dbbs;

uses crt,dos,comms,sound,printer;

{$I lastrev.inc}

{$I english.inc}

{$I aurdefs.inc}

{$I crc16.inc}

type
 userrec=record
          name:string[30];
          password:string[30];
          access:byte;
         end;

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

 currentdir,olddir,command,tail:string;
 getout:boolean;
 stsec:shortint;
 stmin:shortint;
 sthour:shortint;
 secon:shortint;
 minon:shortint;
 houron:shortint;
 curruser,fileuser:userrec;
 bbs:boolean;

{**************************************************************************}

procedure em_install(b:emtype);

begin
 {Dummy procedure required by the SETUP include file}
end;

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
 parities:array[no_par..od_par] of char=('N','E','O');
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
 temp:='  AHOST   і '+s1+' і '+
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

procedure log(var f:text;s:string);

begin
 writeln(s);
 writeln(f,s);
end;

{**************************************************************************}

{$F+}procedure exitroutine;{$F-}

begin
 if running then closecomms;
 window(1,1,80,25);
 normvideo;
 clrscr;
 cursoron;
 if erroraddr=nil then writeln('Thanks for using AHOST.') else begin
  str(exitcode,s);
  log(logfile,'! Abnormal program termination. Please report code '+s);
  writeln;
 end;
 s:=getstatus;
 writeln(logfile,#13#10'  AHOST exited at '+time+' on the '+date);
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
 case c[1] of
  BS : s:=bs+space+bs;
  TAB: begin
        b:=9-(wherex mod 8);
        s:=stringof(space,b);
       end;
  ^L : clrscr;
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
 log(logfile,'  Executing '+command+space+tail);
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
 writeln(lf+
  cr+lf+'  ЬЫЫЬ   ЫЫЫ  ЫЫЫ ЬЫЫЯЯЫЫЬ ЬЫЫЯЯЫЫЬ ЯЯЫЫЫЯЯЯ    Complete Communications'
 +cr+lf+'ЬЫЫЯЯЫЫЬ ЫЫЫ  ЫЫЫ ЫЫЫ  ЫЫЫ ЫЫЫ  ЯЯЯ   ЫЫЫ               Software'
 +cr+lf+'ЫЫЫЬЬЫЫЫ ЫЫЫЬЬЫЫЫ ЫЫЫ  ЫЫЫ  ЯЫЫЫЫЬ    ЫЫЫ',
  cr+lf+'ЫЫЫ  ЫЫЫ ЫЫЫ  ЫЫЫ ЫЫЫ  ЫЫЫ ЬЬЬ  ЫЫЫ   ЫЫЫ        Designed and Coded by'
 +cr+lf+'ЫЫЫ  ЫЫЫ ЫЫЫ  ЫЫЫ ЯЫЫЬЬЫЫЯ ЯЫЫЬЬЫЫЯ   ЫЫЫ         Michael E. Ralphson'
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

procedure quit;

var
 c:char;
 prompt,keys:string[80];

begin
 prompt:='Exit to DOS';
 keys:='y';
 openwin(10,5,70,7,save,oldx,oldy,true,'Exit AHOST');
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


function properdir:string;

var
 temp:string;

begin
 temp:=currentdir;
 if temp[length(temp)]='\' then dec(temp[0]);
 properdir:=temp;
end;

procedure typefile(s:string);

var
 f:text;
 lines:byte;

begin
 if not bbs then writeln;
 assign(f,s);
 reset(f);
 if ioresult=0 then begin
  lines:=0;
  repeat
   readln(f,s);
   writeln(s);
   inc(lines);
   if keypressed then if readkey=#3 then begin
    writeln('^C');
    exit;
   end;
   if lines>21 then begin
    write(#10' [More...]'#13);
    c:=readkey;
    if c=#3 then begin
     writeln('^C');
     exit;
    end;
    lines:=0;
    write('          '#13);
   end;
  until eof(f);
  close(f);
 end else if not bbs then writeln('File not found');
end;

procedure init;

begin
 bbs:=true;
 typefile('welcome.txt');
 getdir(0,olddir);
 currentdir:='C:\';
 chdir(currentdir);
 getout:=false;
 bbs:=false;
end;

procedure logon;

var
 a:byte;

begin
 gettime(hour,min,sec,loop);
 sthour:=hour;
 stmin:=min;
 stsec:=sec;
 write('Name: ');
 readln(curruser.name);
 write('Password: ');
 a:=textattr;
 textattr:=0;
 readln(curruser.password);
 textattr:=a;
end;

procedure dire;

var
 sr:searchrec;
 wide:boolean;
 spsn,lines,max:byte;
 files:word;
 bytes:longint;
 s:string;

begin
 files:=0;
 bytes:=0;
 lines:=0;
 max:=20;
 spsn:=pos('/W',tail);
 wide:=spsn>0;
 if wide then delete(tail,spsn,2);
 if tail='' then tail:='*.*';
 s:='Directory of '+fexpand('.');
 if s[length(s)]<>'\' then s:=s+'\';
 s:=s+tail;
 writeln(#10+s+#10);
 findfirst(properdir+'\'+tail,directory,sr);
 while doserror=0 do begin
  write(sr.name);
  inc(files);
  inc(bytes,sr.size);
  repeat
   write(' ');
  until wherex mod 20=1;
  if wide then else
  if sr.attr and directory=directory then writeln('DIRECTORY') else
   writeln(sr.size:9);
  if wide then if wherex=0 then inc(lines);
  if not wide then inc(lines);
  if keypressed then if readkey=#3 then begin
   writeln(#13#10'^C');
   exit;
  end;
  if lines>max then begin
   write(' [More...]'#13);
   c:=readkey;
   if c=#3 then begin
    writeln(#13#10'^C');
    exit;
   end;
   lines:=0;
   max:=21;
   write('          '#13);
  end;
  findnext(sr);
 end;
 if wherex<>1 then writeln;
 writeln(#10,files,' files totalling ',bytes,' bytes. ',diskfree(0),' bytes free.');
end;

procedure cd;

var
 s:string;

begin
 if tail='' then writeln(#10+'Current directory: '+currentdir) else begin
  if (tail<>'\') and (tail[2]<>':') then begin
   if tail[length(tail)]='\' then dec(tail[0]);
   if tail[1]<>'\' then tail:=properdir+'\'+tail;
  end;
  chdir(tail);
  if ioresult<>0 then writeln('Invalid path');
  getdir(0,currentdir);
 end;
end;

function f(n:word;l:byte):string;

begin
end;

procedure timedate;

var
 hun,year,month,day,dow:word;

const
 monthname:array [1..12] of string[9]=('January','February','March','April',
           'May','June','July','August','September','October','November','December');
 dayname:array [0..6] of string[6]=('Sun','Mon','Tues','Wednes','Thurs','Fri',
         'Satur');

begin
 gettime(hour,min,sec,hun);
 getdate(year,month,day,dow);
 write(#10'It is '+itos(hour,2)+':'+itos(min,2)+':'+itos(sec,2)+' on '+
       dayname[dow]+'day the ',day);
 case day of
  1,21,31:write('st');
  2,22:write('nd');
  else write('th');
 end;
 writeln(' of '+monthname[month]+' ',year);
 secon:=sec-stsec;
 minon:=min-stmin;
 houron:=hour-sthour;
 if secon<0 then begin
  inc(secon,60);
  dec(minon);
 end;
 if minon<0 then begin
  inc(minon,60);
  dec(houron);
 end;
 if houron<0 then inc(houron,24);
 writeln;
 writeln('You have been on-line for ',houron,' hours, ',minon,' minutes and ',
         secon,' seconds.');
end;

procedure help;

begin
 writeln('');
 writeln('TYPE      Display text file to the screen');
 writeln('CD        Display or change directory');
 writeln('CLS       Clear screen');
 writeln('DIR       Display directory (/W for wide)');
 writeln('TIME      Displays current time, date and call duration');
 writeln('DATE      (See time)');
 writeln('EXIT      Hang up');
end;

{$I xmodem.inc}

var
 temp:string;

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
  log(logfile,'! Error '+s+' reading configuration file');
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
 writeln(logfile,#10#13'  AHOST started at '+time+' on the '+date);

 parameter:=ucase(paramstr(1));

 if parameter='SETUP' then begin
  log(logfile,'  User requested configuration');
  setupmenu;
  exit;
 end;

 if gosetup then setupmenu;

 initialise;
 init;
 logon;
 repeat
  status;
  writeln;
  write(currentdir+'>');
  readln(tail);
  for loop:=1 to length(tail) do tail[loop]:=upcase(tail[loop]);
  while tail[1]=' ' do delete(tail,1,1);
  loop:=1;
  while (loop<=length(tail)) and (tail[loop] in ['A'..'Z']) do inc(loop);
  command:=copy(tail,1,pred(loop));
  delete(tail,1,pred(loop));
  while tail[1]=' ' do delete(tail,1,1);
  if (command='') and (tail='?') then help else
  if command='TYPE' then typefile(tail) else
  if command='CD' then cd else
  if command='CLS' then clrscr else
  if command='DIR' then dire else
  if (command='TIME') or (command='DATE') then timedate else
  if command='SET' then setupmenu else
  if command='BYE' then hangup(true) else
  if command='EXIT' then getout:=true
  else if (length(command)=1) and (tail=':') then begin
   tail:=command+':\';
   cd;
  end else writeln(#10'Bad command or filename');
 until getout;
 chdir(olddir);
 window(1,1,80,25);
 clrscr;
end.
