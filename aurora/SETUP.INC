procedure noisesetup;

var
 nschoice:byte;

begin
 nschoice:=1;
 option[0]:='Sound Setup';
 repeat
  option[1]:='All Sounds : O'+onoff[setup.sound];
  option[2]:='Bell Noise : '+setup.beep;
  option[3]:='Logon Noise: '+setup.logon;
  menu(nschoice,3,0);
  case nschoice of
   1:setup.sound:=not setup.sound;
   2:getstring(setup.beep,20,'Bell Noise');
   3:getstring(setup.logon,40,'Logon Noise');
   else;
  end;
 until nschoice=0;
end;

{**************************************************************************}

procedure screensetup;

var
 colour,sschoice:byte;

begin
 sschoice:=1;
 repeat
  option[0]:='Screen and Colour';
  option[1]:='Main foreground colour';
  option[2]:='Main background colour';
  option[3]:='Window foreground colour';
  option[4]:='Window background colour';
  option[5]:='Menu option key colour';
  option[6]:='Window border style';
  option[7]:='Highlight foreground colour';
  option[8]:='Highlight background colour';
  option[9]:='Direct screen writes O'+onoff[setup.direct];
  option[10]:='Snow checking O'+onoff[setup.snow];
  colour:=(setup.bclr shl 4) or setup.fclr;
  for loop:=1 to 1920 do dosptr^[loop shl 1]:=colour;
  textattr:=colour;
  menu(sschoice,10,0);
  case sschoice of
   1:setup.fclr:=succ(setup.fclr) and 15;
   2:setup.bclr:=succ(setup.bclr) and 7;
   3:setup.wfclr:=succ(setup.wfclr) and 15;
   4:setup.wbclr:=succ(setup.wbclr) and 7;
   5:setup.wsclr:=succ(setup.wsclr) and 15;
   6:setup.winstyle:=succ(setup.winstyle) mod 10;
   7:setup.hfclr:=succ(setup.hfclr) and 15;
   8:setup.hbclr:=succ(setup.hbclr) and 7;
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
 repeat
  option[0]:='File Setup';
  option[1]:='Upload path  : '+setup.updir;
  option[2]:='Download path: '+setup.downdir;
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

procedure termsetup;

var
 tschoice:byte;

begin
 tschoice:=1;
 repeat
  option[0]:='Terminal Settings';
  option[1]:='Emulation mode '+em_names[current_em];
  option[2]:='Allow ANSI in AVATAR O'+onoff[setup.ansiavatar];
  option[3]:='Auto Zmodem Download O'+onoff[setup.zmodauto];
  option[4]:='Local echo O'+onoff[echo];
  option[5]:='Add line feeds O'+onoff[addlf];
  option[6]:='Modem lights O'+onoff[lights];
  option[7]:='Operator: '+setup.caller;
  option[8]:='Location: '+setup.location;
  menu(tschoice,8,0);
  case tschoice of
   1:begin
      inc(current_em);
      if current_em>teletype then current_em:=ansi;
      setup.emu:=current_em;
      em_install(current_em);
     end;
   2:setup.ansiavatar:=not setup.ansiavatar;
   3:setup.zmodauto:=not setup.zmodauto;
   4:begin
      echo:=not echo;
      setup.defecho:=echo;
     end;
   5:begin
      addlf:=not addlf;
      setup.deflinefeed:=addlf;
     end;
   6:begin
      lights:=not lights;
      setup.deflights:=lights;
     end;
   7:begin
      getstring(setup.caller,40,'Default Terminal User');
      username:=setup.caller;
     end;
   8:getstring(setup.location,40,'Usual Location');
   else;
  end;
 until tschoice=0;
end;

{**************************************************************************}

procedure modemsetup;

var
 mschoice:byte;
 s:string;
 loop:byte;

begin
 mschoice:=1;
 repeat
  option[0]:='Modem Setup';
  option[1]:='Initialise : '+setup.cmdinit;
  option[2]:='Hang up    : '+setup.cmdhangup;
  option[3]:='Dial prefix: '+setup.cmdpredial;
  option[4]:='Auto-Answer: '+setup.cmdanswer;
  option[5]:='Dial aborts: '+setup.abortdial;
  str(setup.dialtime,s);
  option[6]:='Dial time : '+s;
  str(setup.dialpause,s);
  option[7]:='Dial pause: '+s;

  menu(mschoice,7,0);

  case mschoice of
   1:getstring(setup.cmdinit,40,'Initialise');
   2:getstring(setup.cmdhangup,40,'Hang Up');
   3:getstring(setup.cmdpredial,40,'Dial Prefix');
   4:getstring(setup.cmdanswer,40,'Auto-Answer');
   5:getstring(setup.abortdial,76,'Modem Responses to Abort Dialling');
   6:begin
      inc(setup.dialtime,5);
      if setup.dialtime>60 then setup.dialtime:=20;
     end;
   7:begin
      inc(setup.dialpause,5);
      if setup.dialpause>45 then setup.dialpause:=5;
     end;
   else;
  end;
 until mschoice=0;
end;

{**************************************************************************}

procedure commsetup;

const
 dircon:array [false..true] of string[6]=('Modem','Direct');

var
 cschoice:byte;
 bips:byte;
 temp:string;
 reset:boolean;

begin
 reset:=false;
 cschoice:=1;
 repeat
  option[0]:='Comms Setup';
  option[1]:='Bits per Second: '+curspeed;
  option[2]:='COM Port: '+curport;
  option[4]:='Parity: '+parsetting[setup.parity];
  str(setup.length,temp);
  option[3]:='Data Length '+temp+' bits';
  str(setup.stopbits,temp);
  option[5]:='Stop-Bits: '+temp;
  option[6]:=dircon[setup.nulmodem]+' connection';
  option[7]:='Locked Baud Rate O'+onoff[setup.lockdte];
  menu(cschoice,7,0);
  case cschoice of
   1:begin
      bips:=1;
      while setup.baud<>bpsrate[bips] do inc(bips);
      inc(bips);
      if bips>9 then bips:=1;
      setup.baud:=bpsrate[bips];
      str(bpsrate[bips]:6,curspeed);
     end;
   2:begin
      inc(setup.comport);
      if setup.comport>4 then setup.comport:=1;
      str(setup.comport,curport);
      reset:=true;
     end;
   4:begin
      inc(setup.parity);
      if setup.parity>4 then setup.parity:=0;
     end;
   3:begin
      inc(setup.length);
      if setup.length>8 then setup.length:=5;
     end;
   5:begin
      inc(setup.stopbits);
      if setup.stopbits>2 then setup.stopbits:=1;
     end;
   6:begin
      setup.nulmodem:=not setup.nulmodem;
      direct:=setup.nulmodem;
     end;
   7:setup.lockdte:=not setup.lockdte;
   else;
  end;
 until cschoice=0;
 if running then begin
  if reset then closecomms;
  with setup do setport(comport,baud,parity,length,stopbits);
  if reset then opencomms;
 end;
end;

{**************************************************************************}

procedure setupmenu;

var
 smchoice:byte;
 s:string;

begin
 smchoice:=1;
 repeat
  option[0]:='Setup';
  option[1]:='Screen and colour';
  option[2]:='Sound effects';
  option[3]:='Filenames and paths';
  option[4]:='Terminal settings';
  option[5]:='Modem and dialling';
  option[6]:='Communications settings';
  option[7]:='Write settings to disk';
  menu(smchoice,7,0);
  case smchoice of
   1:screensetup;
   2:noisesetup;
   3:filesetup;
   4:termsetup;
   5:modemsetup;
   6:commsetup;
   7:begin
      assign(setupfile,cfgname);
      rewrite(setupfile);
      write(setupfile,setup);
      close(setupfile);
      if ioresult<>0 then beep;
     end;
   else;
  end;
 until smchoice=0;
end;
