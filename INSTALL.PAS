{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 1024,0,655360}
program install;

uses dos,crt;

{$I lastrev.inc}

{$I version.inc}

{$I english.inc}

procedure centre(s:string);

begin
 gotoxy(round((80-length(s))/2),wherey);
 writeln(s);
end;

function ncopy(source,dest:string):boolean;

type
 FileBuffer = array[1..65000] of byte;

var
 InFile,
 OutFile : file;
 BlocksRead,
 BlocksWritten,
 BufSize : word;
 buf : ^FileBuffer;

begin
  BufSize := SizeOf(FileBuffer);
  if BufSize > MaxAvail then
    BufSize := MaxAvail;
  GetMem(buf, BufSize);
  Assign(InFile, Source);
  Reset(Infile, 1);
  Assign(OutFile, Dest);
  Rewrite(OutFile, 1);
  repeat
    BlockRead(Infile, buf^, BufSize, BlocksRead);
    BlockWrite(OutFile, buf^, BlocksRead, BlocksWritten);
    if BlocksWritten < BlocksRead then begin
        writeln(_disk_full);
        blocksRead:=0;
       end;
  until (BlocksRead < BufSize);
  FreeMem(buf, BufSize);
  Close(InFile);
  Close(OutFile);
  ncopy:=true;
end;

var
 start,temp:string;
 make,change:word;
 f:searchrec;
 loop:byte;

begin
 directvideo:=false;
 clrscr;
 writeln;
 centre(_ins_title);
 writeln;
 centre('V'+version+' ('+lastrev+'), Copyright (c) 1991 Michael E. Ralphson');
 writeln;
 getdir(0,start);

 writeln;
 centre(_ins_mesg1+start+_ins_mesg2); {Installing from, to}
 writeln;
 change:=0;
 mkdir('C:\APNS');
 make:=ioresult+doserror;
 mkdir('C:\APNS\SEND');
 make:=ioresult+doserror;
 mkdir('C:\APNS\RECV');
 make:=ioresult+doserror;
 doserror:=0;
 chdir('C:\APNS\RECV');
 inc(change,ioresult+doserror);
 chdir('C:\APNS\SEND');
 inc(change,ioresult+doserror);
 chdir('C:\APNS');
 inc(change,ioresult+doserror);
 if change<>0 then begin
  centre(_ins_nocreate);
  chdir(start);
  exit;
 end;
 chdir(start);

 findfirst('*.*',0,f);
 while doserror=0 do begin
  temp:='';
  for loop:=1 to length(f.name) do temp:=temp+upcase(f.name[loop]);
  if temp<>'INSTALL.EXE' then begin
   write(' '+temp);
   if ncopy(temp,'C:\APNS\'+temp) then write(#13'             '#13)
   else writeln(_ins_copyfail);
  end;
  findnext(f);
 end;
 centre(_ins_complete);
end.
