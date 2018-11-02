{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 4096,0,65000}
program install;

uses dos,crt;

type
 comport=record
  base:word;
  irq:byte;
  int:byte;
 end;
 filebuffer=array [1..64512] of byte;

var
 buf:^filebuffer;

{$I lastrev.inc}
{$I apdefs.inc}

procedure centre(s:string);

begin
 gotoxy(round((80-length(s))/2),wherey);
 write(s);
end;

function ncopy(source,dest:string):boolean;

var
 infile,outfile:file;
 blocksread,blockswritten:word;

begin
 ncopy:=false;
 assign(infile,source);
 reset(infile,1);
 assign(outfile,dest);
 rewrite(outfile,1);
 if ioresult<>0 then exit;
 repeat
  blockread(infile,buf^,64512,blocksread);
  blockwrite(outfile,buf^,blocksread,blockswritten);
  if blockswritten<blocksread then begin
   writeln(' Disk Full');
   blocksread:=0;
  end;
 until (blocksread<64512);
 close(infile);
 close(outfile);
 ncopy:=true;
end;

var
 start,temp:string;
 make,change:word;
 f:searchrec;
 x,y,loop:byte;
 drive,c:char;
 configdone:boolean;

begin
 drive:='C';
 c:='N';
 directvideo:=true;
 checksnow:=false;
 checkbreak:=false;
 clrscr;
 writeln;
 centre('Automated Polling Network System (APNS) Installation');
 writeln(#10);
 centre('Version '+version+', Copyright (c) 1993 Michael E. Ralphson');
 writeln(#10);
 getdir(0,start);

 if maxavail>=64512 then getmem(buf,64512) else begin
  centre('Not enough memory to install APNS');
  writeln(#7);
  exit;
 end;

 if paramcount>0 then begin
  temp:=paramstr(1);
  drive:=upcase(temp[1]);
 end;
 writeln;
 
 if start<>drive+':\APNS' then begin
  centre('Installing from '+start+' to '+drive+':\APNS'); 
  writeln(#10);
  centre('Is this correct (Y/N) ?');
  repeat
   c:=upcase(readkey);
  until (c='Y') or (c='N');
 end else centre('Source and destination paths are the same.');
 writeln(#10);
 if c='N' then begin
  centre('Restart the program with the correct drive letter, eg: INSTALL F:');
  writeln;
  exit;
 end;
 change:=0;
 mkdir(drive+':\APNS');
 make:=ioresult+doserror;
 mkdir(drive+':\APNS\SEND');
 make:=ioresult+doserror;
 mkdir(drive+':\APNS\RECV');
 make:=ioresult+doserror;
 doserror:=0;
 chdir(drive+':\APNS\RECV');
 inc(change,ioresult+doserror);
 chdir(drive+':\APNS\SEND');
 inc(change,ioresult+doserror);
 chdir(drive+':\APNS');
 inc(change,ioresult+doserror);
 if change<>0 then begin
  centre('Could not create directories');
  writeln;
  chdir(start);
  exit;
 end;
 chdir(start);

 findfirst('*.*',0,f);
 while doserror=0 do begin
  temp:=f.name;
  if (temp<>'INSTALL.EXE') and (pos('.CFG',temp)=0) then begin
   gotoxy(27,wherey);
   write('Installing: ',temp:12);
   if not ncopy(temp,drive+':\APNS\'+temp) then writeln(#7' Could not be copied');
  end;
  findnext(f);
 end;
 
 configdone:=false;
 findfirst('*.CFG',0,f);
 while doserror=0 do begin
  if not configdone then begin
   temp:=f.name;
   gotoxy(27,wherey);
   if length(temp)>8 then begin
    write('Install ',temp:12,' (Y/n)');
    c:=upcase(readkey);
   end else begin
    write('Installing: ',temp:12);
    c:='Y';
   end; 
   if c<>'N' then begin
    if not ncopy(temp,drive+':\APNS\APNS.CFG') then begin
     writeln(#7' Could not be copied');
    end else configdone:=true;
   end; 
  end;
  findnext(f);
 end;
 
 write(#13);
 clreol;
 writeln;
 chdir(drive+':\APNS');
 exec(getenv('COMSPEC'),'/C APCONFIG.EXE SETDIR');
 writeln;
 centre('Installation complete');
 writeln(#10);
 centre('Type APNS WAIT or APNS DIAL to start');
 writeln;
end.
