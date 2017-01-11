var
 current,temp:dialentry;
 dialfile:file of dialentry;

const
 last:longint=0;

{**************************************************************************}

function picklist(title:string):longint;

var
 oldef,default,oldfirst,first,max:longint;
 x,y:byte;
 c:char;
 endnow:boolean;
 loop:byte;
 s:string;

begin
 cursoroff;
 endnow:=false;
 if last>=20 then max:=19 else max:=pred(last);
 openwin(18,2,62,max+4,store,x,y,true,title);
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
        while (max<pred(last)) and (loop<20) do begin
         inc(first);
         inc(max);
         inc(default);
         inc(loop);
        end;
        if oldef<first then oldef:=first;
       end;
   #73:begin
        loop:=0;
        while (first>0) and (loop<20) do begin
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
   #44:onlinehelp(title);
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

procedure dialmenu(picked:longint;var getout:byte);

var
 now,target:longint;
 attempts:word;
 loop,temp:byte;
 c:char;
 send,modem:string[80];
 thour,tmin,tsec:word;
 endnow,talking:boolean;

begin
 endnow:=false;
 modem:='None';
 attempts:=0;
 if picked<0 then picked:=picklist('Dial');
 if picked>=0 then begin

  with current do setport(setup.comport,bips,parity,datlen,stopbits);
  str(current.bips:6,curspeed);
  username:=current.caller;
  password:=current.password;

  openwin(2,2,78,11,save,oldx,oldy,true,'Dialling');
  repeat
   clrscr;
   inc(attempts);
   send:=current.prefix+current.number+cr;
   for loop:=1 to length(send) do begin
    rawsend(send[loop]);
    delay(10);
    while charwaiting do temp:=getaux;
   end;
   talking:=false;
   writeln;
   log('  Dialling '+current.name+', '+current.number);
   writeln;
   str(attempts,send);
   log('  Attempt '+send+'. Last message: '+modem);
   writeln;
   centre('Escape to abort, any other key to re-dial');
   writeln(lf);
   delay(3000);
   status;
   thour:=hour;
   tmin:=min;
   tsec:=sec;
   inc(tsec,setup.dialtime);
   if tsec>59 then begin
    inc(tmin);
    dec(tsec,60);
   end;
   if tmin>59 then begin
    inc(thour);
    dec(tmin,60);
   end;
   if thour>23 then thour:=0;
   target:=(thour*3600)+(tmin*60)+tsec;
   laststr:='';
   cursoroff;
   repeat
    while charwaiting do begin
     quiet;
     delay(10);
    end;
    status;
    now:=(hour*3600)+(min*60)+sec;
    if now>target then dec(now,86400);
    str(target-now:2,send);
    centre('Time for connect: '+send);
    talking:=(laststr<>'') and (pos(laststr,setup.abortdial)>0);
   until (now=target) or talking or keypressed or carrierdetect;
   cursoron;
   if carrierdetect then endnow:=true else
   if talking then begin
    modem:=laststr;
    now:=target;
   end else
   if keypressed then begin
    c:=readkey;
    if c=ESC then begin
     sendaux(13);
     endnow:=true;
     delay(250);
     while charwaiting do quiet;
    end else now:=target;
   end;
   if (now=target) and (not carrierdetect) then begin
    sendaux(13);
    writeln;
    anykey(setup.dialpause,false);
    while charwaiting do begin
     quiet;
     delay(10);
    end;
    modem:=laststr;
   end;
  until endnow;
  closewin(save,oldx,oldy);
  if carrierdetect then begin
   if setup.lockdte then begin
    with current do setport(setup.comport,setup.baud,parity,datlen,stopbits);
    str(setup.baud:6,curspeed);
   end;
   inc(current.totalcalls);
   seek(dialfile,picked);
   write(dialfile,current);
   writeln(logfile,'œ Connected to ',current.name);
   echo:=current.echo;
   addlf:=current.linefeed;
   current_em:=current.emu;
   em_install(current_em);
   status;
   if setup.sound then play(setup.logon);
   getout:=0;
   while charwaiting do quiet;
   log('* '+laststr);
   send:=current.script+'.SCR';
   if exist(send) then script(send);
  end;
 end;
end;

{**************************************************************************}

procedure editmenu(title:string;seekto:longint);

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
  option[1]:='BBS Name : '+current.name;
  option[2]:='Number   : '+current.number;
  option[3]:='Prefix   : '+current.prefix;
  option[4]:='Username : '+current.caller;
  option[5]:='Password : '+stringof('*',length(current.password));
  option[6]:='Script   : '+current.script;
  str(current.bips:6,s);
  option[7]:='Baud Rate: '+s;
  str(current.datlen,s);
  option[8]:='Length   : '+s;
  option[9]:='Parity   : '+parsetting[current.parity];
  str(current.stopbits,s);
  option[10]:='Stop Bits: '+s;
  option[11]:='Line Feeds O'+onoff[current.linefeed];
  option[12]:='Local Echo O'+onoff[current.echo];
  option[13]:='Emulation: '+em_names[current.emu];
  option[14]:='Use IEMSI  O'+onoff[current.iemsi];
  option[15]:='IEMSI Req: '+current.iemsifunc;
  option[16]:='1st Call : ';
  option[17]:='Last Call: ';
  str(current.totalcalls,s);
  option[18]:='No. Calls: '+s;
  menu(emchoice,18,0);
  case emchoice of
   1:getstring(current.name,40,'Name');
   2:getstring(current.number,40,'Number');
   3:getstring(current.prefix,40,'Dial Prefix');
   4:getstring(current.caller,40,'User Name');
   5:getstring(current.password,40,'Password');
   6:getstring(current.script,8,'Script name, no directory or extension');
   7:begin
      bips:=1;
      while current.bips<>bpsrate[bips] do inc(bips);
      inc(bips);
      if bips>9 then bips:=1;
      current.bips:=bpsrate[bips];
     end;
   8:begin
      inc(current.datlen);
      if current.datlen>8 then current.datlen:=7;
     end;
   9:begin
      inc(current.parity);
      if current.parity>2 then current.parity:=0;
     end;
  10:begin
      inc(current.stopbits);
      if current.stopbits>2 then current.stopbits:=1;
     end;
   11:current.linefeed:=not current.linefeed;
   12:current.echo:=not current.echo;
   13:begin
      inc(current.emu);
      if current.emu>teletype then current.emu:=ansi;
     end;
   14:current.iemsi:=not current.iemsi;
   15:getstring(current.iemsifunc,20,'IEMSI Request');
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
 current.datlen:=setup.length;
 current.parity:=setup.parity;
 current.stopbits:=setup.stopbits;
 current.bips:=setup.baud;
 current.linefeed:=addlf;
 current.echo:=echo;
 current.emu:=current_em;
 current.iemsi:=true;
 current.iemsifunc:='HPENMFS';
 current.caller:=setup.caller;
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

procedure autodial;

var
 request,service:string;
 loop:byte;
 number:longint;
 go:byte;

begin
 request:=paramstr(2);
 request:=ucase(request);
 number:=-1;
 repeat
  inc(number);
  read(dialfile,current);
  service:=ucase(current.name);
  go:=pos(request,service);
 until (go>0) or eof(dialfile);
 if go>0 then dialmenu(number,go)
  else log('! No dialing directory entry matching '+request);
 halt(0);
end;

{**************************************************************************}

procedure dialdir;

var
 ddchoice:byte;
 picked:longint;

begin
 assign(dialfile,homepath+'AURORA.FON');
 reset(dialfile);
 if ioresult>0 then begin
  rewrite(dialfile);
  reset(dialfile);
 end;
 last:=filesize(dialfile);
 ddchoice:=1;
 if paramcount>1 then autodial;
 repeat
  option[0]:='Dialling Directory';
  str(last,s);
  option[1]:='Dial an entry ['+s+']';
  option[2]:='Add a new entry';
  option[3]:='Edit an existing entry';
  option[4]:='Delete an existing entry';
  menu(ddchoice,4,0);
  case ddchoice of
   1:if (not carrierdetect) and (last>0) then dialmenu(-1,ddchoice) else beep;
   2:addmenu;
   3:if last>0 then begin
      picked:=picklist('Edit');
      if picked>=0 then editmenu('Edit an entry',picked);
     end else beep;
   4:if last>0 then deletemenu else beep;
   else;
  end;
 until ddchoice=0;
 close(dialfile);
end;
