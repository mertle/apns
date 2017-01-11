{$A+,B-,D-,E-,F-,G+,I-,L-,N-,O-,R-,S+,V-,X+}
{$M 16384,0,0}

program apfile;

uses test186,crt,dos,utility,random6;

type
 listrec=record
  Mark:Byte;
  Attr:Byte;
  Time:Longint;
  Size:Longint;
  Name:string[12];
 end;
 filelist=array [1..2500] of listrec;
 flptr=^filelist;
 smode=(none,fname,extn,age,size);
 pickact=(seekto,readrec,retmax);
 comport=record
  base:word;
  irq:byte;
  int:byte;
 end;

const
 space=' ';
 mark=4;
 cr=#13;
 lf=#10;
 esc=#27;
 nul=#0;
 last:longint=0;
 
{$I apdefs.inc}
{$I runerr.inc}

var
 currsite:dialentry;
 dialfile:file of dialentry;
 ioerror:integer;
 loop,crc,pickpos,buf1h,buf2h:word;
 exitsave:pointer;
 setupfile:file of config;
 hour,min,sec:word;
 dirs,files1,files2:word;
 picked,tags:longint;
 fl1:flptr;
 fl2:flptr;
 sortmode:smode;
 nomem,getout,readnow:boolean;
 cfgname:string[128];
 c:char;
 fkey:byte;
 pick:procedure(act:pickact;var s:string;var n:longint);
 pickletter:array ['A'..'Z'] of longint;
 time,date:string[10];
 s,statusline,helpline,oldhelp:string[80];
 option:array [0..20] of string[60];
 ophelp:array [0..20] of string[60];
 lhastr,startupdir,currentdir,title:string[128];
 sr:listrec;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 listfile:text;
 listname:string;
 equiplist:word absolute $40:$10;

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
 temp:=' '+date+' ³ ApFile, APNS File Manager version '+version;
 while length(temp)<71 do temp:=temp+' ';
 temp:=temp+time+' ';
 getstatus:=temp;
end;

{**************************************************************************}

procedure mstatus; far;

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

procedure exitroutine; far;

begin
 exitproc:=exitsave;
 encrconf;
 cursoron;
 if erroraddr<>nil then begin
  s:=runerror(exitcode);
  writeln('! Please report '+s);
  writeln;
  erroraddr:=nil;
 end;
end;

{**************************************************************************}

procedure checkerror(s:string);

begin
 ioerror:=ioresult;
 if ioerror<>0 then begin
  writeln('! '+runerror(ioerror)+' '+s);
  halt;
 end;
end; 

{**************************************************************************}

procedure fileview(fn:string);

var
 f:text;
 stopnow:boolean;
 lines:byte;
 s:string[80];
 handle:word;

begin
 stopnow:=false;
 assign(f,fn);
 reset(f);
 if ioresult=0 then begin
  if not(eof(f)) then begin
   handle:=openwin(2,3,79,23,'Archive View');
   lines:=0;
   repeat
    readln(f,s);
    if length(s)>76 then s[0]:=#76;
    inc(lines);
    if lines>21 then begin
     repeat status until keypressed;
     if readkey=ESC then stopnow:=true;
     lines:=0;
     clrscr;
    end else
    if lines=21 then write(space,s)
    else writeln(space,s);
   until (eof(f)) or (stopnow);
   close(f);
   if not stopnow then begin
    repeat status until keypressed;
    while keypressed do readkey;
   end;
   closewin(handle);
  end;
 end;
end;

{*************************************************************************}

function showfile(sr:listrec):string;

var
 temp,t2:string[45];
 loop:word;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 dt:datetime;

begin
 if sr.name<>'..' then begin
  fsplit(sr.name,dir,name,ext);
  temp:=name;
  if temp='' then temp:=dir;
  while length(temp)<8 do temp:=temp+' ';
  temp:=temp+ext;
  while length(temp)<12 do temp:=temp+' ';
 end else temp:='..          ';
 if sr.attr=directory then t2:=' ÄÄ DIR ÄÄ' else str(sr.size:10,t2);
 temp:=temp+t2+' ';
 unpacktime(sr.time,dt);
 t2:='';
 t2:=itos(dt.day,2)+'/';
 t2:=t2+itos(dt.month,2)+'/';
 t2:=t2+itos(dt.year,4)+' ';
 temp:=temp+t2;
 t2:='';
 t2:=itos(dt.hour,2)+':';
 t2:=t2+itos(dt.min,2)+':';
 t2:=t2+itos(dt.sec,2);
 temp:=chr(sr.mark)+' '+temp+t2+' ';
 showfile:=temp;
end;

{*************************************************************************}

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

procedure pickfile(act:pickact;var s:string;var n:longint); far;

begin
 s:='';
 case act of
  seekto:pickpos:=n;
  readrec:begin
           s:=showfile(fl2^[succ(pickpos)]);
           inc(pickpos);
          end;
  retmax:n:=files2;
  else;
 end;
end; 

{*************************************************************************}

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
  c:=upcase(s[3]);
  if (pickletter[c]=-1) and (s[1]<>#255) then pickletter[c]:=loop;
 end; 
end;

{*************************************************************************}

function picklist(title:string):longint;

var
 oldef,default,oldfirst,first,max,last,temp,loop:longint;
 x,y,k,f:byte;
 c:char;
 endnow:boolean;
 oldcol:byte;
 s,name:string[80];
 handle:word;

 procedure tag(b:byte);

 begin
  if fl2^[succ(default)].attr<>directory then begin
   fl2^[succ(default)].mark:=b;
   fl1^[succ(default)-dirs].mark:=b;
   option[default-first][1]:=chr(b);
   if b=mark then inc(tags) else dec(tags);
  end;
  c:=#0;
  f:=80;
 end;

begin
 fkey:=0;
 pick(retmax,s,last); {get number of records in database}

 if last>0 then begin
  endnow:=false;
  if last>=19 then max:=18 else max:=pred(last);
  handle:=openwin(2,3,46,23,title);
  cursoroff;
  oldfirst:=1;
  first:=0;
  default:=0;
  repeat

   f:=0;

   if oldfirst<>first then begin
    oldfirst:=first;
    pick(seekto,s,first);
    for loop:=first to max do begin
     pick(readrec,s,temp);
     option[loop-first]:=s;
    end;
    for loop:=first to max do begin
     gotoxy(1,(loop-first)+2);
     centre(option[loop-first]);
    end;
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
   c:=upcase(readkey);
   if c=cr then endnow:=true;
   if c=#27 then begin
    endnow:=true;
    default:=-1;
   end;
   
   if c='-' then tag(32);
   if c='+' then tag(mark);

   if c in ['A'..'Z'] then begin
    if pickletter[c]<>-1 then default:=pickletter[c];
    if default in [first..max] then
     {Don't do anything special}
    else
    if last<=19 then begin
     first:=0;
     max:=last;
    end else begin
     first:=default;
     max:=first+18;
     while max>=last do begin
      dec(first);
      dec(max);
     end;
    end;
    if first=oldfirst then c:=' ';
   end; 
   if c=#0 then begin
    if f=0 then k:=ord(readkey) else k:=f;
    case k of
     72:begin
         dec(default);
         if (default<first) and (first>0) then begin
          dec(max);
          dec(first);
         end;
        end;
     80:begin
         inc(default);
         if (default>max) and (max<pred(last)) then begin
          inc(max);
          inc(first);
         end;
        end;
     71:begin
         first:=0;
         max:=18;
         if max>last then max:=last;
         default:=0;
         if oldef>max then oldef:=0;
        end;
     79:begin
         first:=last;
         max:=first+18;
         while max>=last do begin
          dec(first);
          dec(max);
         end;
         default:=max;
         if oldef<first then oldef:=default;
        end;
     81:begin
         loop:=0;
         while (max<pred(last)) and (loop<19) do begin
          inc(first);
          inc(max);
          inc(default);
          inc(loop);
         end;
         if oldef<first then oldef:=first;
        end;
     73:begin
         loop:=0;
         while (first>0) and (loop<19) do begin
          dec(first);
          dec(max);
          dec(default);
          inc(loop);
         end;
         if oldef>max then oldef:=max;
        end;
     59..68:begin
             endnow:=true;
             fkey:=k-58;
             sr:=fl2^[succ(default)];
            end;
     else;
    end;
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

   while keypressed do readkey;

  until endnow;
  killwin(handle);

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

procedure finddrives(fl:flptr;var files:word);

var
 nodiskb:boolean;
 loop:byte;
 avail:longint;
 s:string[26];

begin
 s:=stringof(' ',26);
 fillchar(s[1],2,'Y');
 for loop:=3 to 26 do begin
  avail:=diskfree(loop);
  if avail>=0 then s[loop]:='Y';
 end;
 for loop:=1 to 26 do 
 if (s[loop]='Y') and (chr(loop+64)<>currentdir[1]) then begin
  inc(files);
  fl^[files].name:=chr(loop+64)+':\';
  fl^[files].mark:=255;
  fl^[files].attr:=directory;
 end;
end;

{**************************************************************************}

procedure findfiles(fl:flptr;var files:word);

var
 sr:searchrec;

begin
 files:=0;
 findfirst('*.*',0,sr);
 while doserror=0 do begin
  inc(files);
  move(sr.attr,fl^[files].attr,22);
  fl^[files].mark:=32;
  findnext(sr);
 end;
end;

{**************************************************************************}

procedure finddirs(fl:flptr;var files:word);

var
 sr:searchrec;
 s:string;

begin
 files:=0;
 getdir(0,s);
 if length(s)=3 then finddrives(fl,files);
 findfirst('*.*',directory,sr);
 while doserror=0 do begin
  if (sr.name<>'.') and (sr.attr=directory) then begin
   inc(files);
   move(sr.attr,fl^[files].attr,22);
   fl^[files].mark:=255;
  end;
  findnext(sr);
 end;
end;

{**************************************************************************}

procedure sortfiles(fl:flptr;files:word;sortmode:smode);

{**************************************************************************}

function compare(sr1,sr2:listrec):boolean;

var
 dir:dirstr;
 name:namestr;
 ext:extstr;
 ext1,ext2:string;

begin
 case sortmode of
  extn:begin
        fsplit(sr1.name,dir,name,ext);
        while length(ext)<4 do ext:=ext+' ';
        ext1:=ext+name;
        fsplit(sr2.name,dir,name,ext);
        while length(ext)<4 do ext:=ext+' ';
        ext2:=ext+name;
        compare:=ext1<ext2;
       end;
  age :compare:=sr1.time<sr2.time;
  size:compare:=sr1.size<sr2.size;
  else compare:=sr1.name<sr2.name;
 end; 
end;

{**************************************************************************}

procedure qsort(l,r:integer);

var
 i,j:integer;
 x,y:listrec;

begin
 i:=l;
 j:=r;
 x:=fl^[(l+r) DIV 2];
 repeat
  while compare(fl^[i],x) do inc(i);
  while compare(x,fl^[j]) do dec(j);
  if i<=j then begin
   y:=fl^[i];
   fl^[i]:=fl^[j];
   fl^[j]:=y;
   inc(i);
   dec(j);
  end;
 until i>j;
 if l<j then qsort(l,j);
 if i<r then qsort(i,r);
end;

{**************************************************************************}

var
 first:byte;

begin
 first:=1;
 while (length(fl^[first].name)=3) and (fl^[first].attr=directory) do
  inc(first);
 if sortmode<>none then qsort(first,files);
end;

{**************************************************************************}

function getasite(title:string):string;

var
 last:longint;

begin
 @pick:=@pickdial;
 assign(dialfile,homepath+'APNS.FON');
 reset(dialfile);
 if ioresult<>0 then begin
  rewrite(dialfile);
  reset(dialfile);
 end;
 pickinit;
 last:=filesize(dialfile);
 getasite:='';
 if last>0 then begin
  picked:=picklist(title);
  if picked>=0 then getasite:=currsite.site;
 end else winmsg('Error','There are no entries in the node-list');
 close(dialfile);
end;

{**************************************************************************}

procedure allocbuffers;

begin
 nomem:=false;
 if mem_avail<4032 then nomem:=true else begin
  buf1h:=mem_alloc(4032);
  fl1:=ptr(buf1h,0);
 end;
 if mem_avail<4032 then nomem:=true else begin
  buf2h:=mem_alloc(4032);
  fl2:=ptr(buf2h,0);
 end;
 if nomem then begin
  winmsg('Error','Not enough memory for file lists');
  exit;
 end;
end;

{**************************************************************************}

procedure dumpbuffers;

begin
 mem_free(buf1h);
 mem_free(buf2h);
 readnow:=true;
end;

{**************************************************************************}

procedure lha(s:string);

begin
 dumpbuffers;
 exec(lhastr,s);
 if (doserror>0) or (dosexitcode>0) then begin
  writeln;
  writeln('Could not execute ',lhastr,', check paths or free memory');
  anykey(9,false);
 end;
 allocbuffers;
end;

{**************************************************************************}

function prepscreen:word;

var
 temp:word;

begin
 temp:=openwin(1,1,80,25,'');
 prepscreen:=temp;
 helpline:='Archiving files, please wait...';
 status;
 textattr:=7;
 clrscr;
end;

{**************************************************************************}

procedure makelist;

var
 loop:word;
 sr:searchrec;

begin
 assign(listfile,listname);
 rewrite(listfile);
 for loop:=1 to files1 do begin
  move(fl1^[loop].mark,sr.fill[21],23);
  if sr.fill[21]=mark then writeln(listfile,sr.name);
 end;
 close(listfile);
end;

{**************************************************************************}

procedure doit(s,dest:string);

var
 filename:string;
 loop,handle:word;

begin
 if dest='' then dest:=getasite('Destination');
 if dest<>'' then begin
  filename:=setup.updir+'\'+setup.site+dest+'.LZH';
  handle:=prepscreen;
  if tags>0 then begin
   makelist;
   s:='@'+listname;
  end;
  lha('A /CM '+filename+' '+s);
  closewin(handle);
 end;
end;

{**************************************************************************}

procedure route(s,dest:string);

var
 route:string[4];
 filename1,filename2:string;
 number,handle:word;

begin
 if dest='' then dest:=getasite('Destination');
 if dest<>'' then begin
  route:=getasite('Route Through');
  if route<>'' then begin
   readnow:=true;
   filename2:=setup.updir+'\'+setup.site+dest +'.TRN';
   filename1:=setup.updir+'\'+setup.site+route+'.000';
   handle:=prepscreen;
   if tags>0 then begin
    makelist;
    s:='@'+listname;
   end;
   if dest=route then begin
    writeln('Destination and Route Address are the same. Sending Direct.');
    lha('A /CM '+filename1+' '+s);
   end else begin
    number:=0;
    while exist(filename1) do begin
     filename1:=setup.updir+'\'+setup.site+route+'.'+itos(number,3);
     inc(number);
    end;
    lha('A /CM '+filename2+' '+s);
    lha('M /CMZ '+filename1+' '+filename2);
   end;
   closewin(handle);
  end;
 end;
end;

{**************************************************************************}

var
 handle:word;

begin
 exitsave:=exitproc;
 exitproc:=@exitroutine;

 statusline:='';
 helpline:='';

 listname:=homepath+'APNS.$$$';

 @status:=@mstatus;
 s:=getstatus;

 cfgname:=homepath+'APNS.CFG';
 assign(setupfile,cfgname);
 reset(setupfile);
 checkerror('while opening configuration file');
 read(setupfile,setup);
 checkerror('while reading configuration file');
 close(setupfile);
 
 encrconf;

 crc:=0;
 crc16(crc,security,sizeof(security));
 if crc<>setup.crc then crc:=not crc;
 if crc<>setup.crc then begin
  writeln('! Configuration file has been tampered with');
  exit;
 end;

 {This is the first place the variable SETUP is referenced}

 directvideo:=setup.directvideo;
 checksnow:=setup.snow;

 fillchar(option,sizeof(option),0);

 if scrmode=CO80 then move(setup.fclr,colset,7) else move(monset,colset,7);
 textcolor(setup.fclr);
 textbackground(setup.bclr);
 clrscr;
 allocbuffers;
 cursoroff;
 handle:=openwin(2,3,46,23,' ');
 killwin(handle);
 handle:=openwin(49,3,79,23,'Function Key Guide');
 writeln;
 writeln('  Return selects file or dir.');
 writeln;
 writeln('    F1 to Route the file(s)');
 writeln('    F2 to Route to ALL');
 writeln('    F3 to Send to ALL');
 writeln('    F4 to Sort by Name');
 writeln('    F5 to Sort by Extension');
 writeln('    F6 to Sort by Date');
 writeln('    F7 to Sort by Size');
 writeln('    F8 for an Unsorted list');
 writeln;
 writeln('    + and - to Tag / Untag');
 writeln;
 writeln('    ESC to exit ApFile');
 killwin(handle);
 window(1,1,80,25);

 status;

 getdir(0,startupdir);
 currentdir:=startupdir;
 sortmode:=fname;

 lhastr:=fexpand(fsearch('LHA.EXE',startupdir+';'+getenv('PATH')));

 getout:=false;
 readnow:=true;

 repeat
  helpline:='Use Up, Down, PageUp, PageDown, Home, End and A..Z to choose';
  status;
  
  @pick:=@pickfile;

  if readnow then begin
   tags:=0;
   findfiles(fl1,files1);
   readnow:=false;
  end;

  finddirs(fl2,files2);

  sortfiles(fl2,files2,fname);
  sortfiles(fl1,files1,sortmode);

  move(fl1^[1],fl2^[succ(files2)],sizeof(sr)*files1);
  dirs:=files2;
  inc(files2,files1);

  pickinit;
  title:=currentdir;
  while length(title)>30 do delete(title,1,1);
  picked:=succ(picklist(title));

  if picked=0 then getout:=true;

  if fkey>0 then case fkey of
   1:begin
      if (sr.attr=directory) and (tags=0) then
       winmsg('Error','You cannot route a directory')
      else route(sr.name,'');
     end;
   2:begin
      if (sr.attr=directory) and (tags=0) then 
       winmsg('Error','You cannot route a directory')
      else route(sr.name,'-ALL');
     end;
   3:begin
      if (sr.attr=directory) and (tags=0) then 
       winmsg('Error','You cannot send a directory')
      else doit(sr.name,'-ALL');
     end;
   4:sortmode:=fname;
   5:sortmode:=extn;
   6:sortmode:=age;
   7:sortmode:=size;
   8:begin
      sortmode:=none;
      readnow:=true;
     end;
   10:fileview(sr.name);
   else;
  end else

  if not getout then begin
   readnow:=true;
   sr:=fl2^[picked];
   if sr.attr=directory then begin
    chdir(sr.name);
    if ioresult<>0 then chdir(currentdir);
    getdir(0,currentdir);
   end else doit(sr.name,'');
  end;

 until getout;

 chdir(startupdir);
 if ioresult<>0 then beep;

 assign(listfile,listname);
 erase(listfile);
 if ioresult<>0 then;

 textattr:=7;
 window(1,1,80,25);
 clrscr;

end.
