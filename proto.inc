var
 start:longint; 
 
{**************************************************************************}

procedure setfiletime(s:string;l:longint);

var
 f:file;

begin
 assign(f,s);
 reset(f,1);
 setftime(f,l);
 close(f);
end; 

{**************************************************************************}

function converttime(hour,min,sec,hun:longint):longint;

begin
 converttime:=hun+(sec*100)+(min*6000)+(hour*360000);
end;

{**************************************************************************}

procedure starttimer;

var
 hour,min,sec,hun:word;

begin
 gettime(hour,min,sec,hun);
 start:=converttime(hour,min,sec,hun);
end;

{**************************************************************************}

procedure endtimer(bytes:longint);

var
 cps,hour,min,sec,hun:word;
 finish,diff:longint;
 seconds:real;
 s:string;

begin
 gettime(hour,min,sec,hun);
 finish:=converttime(hour,min,sec,hun);
 if finish<start then inc(finish,8640000);
 diff:=finish-start;
 seconds:=diff/100;
 if seconds<1 then seconds:=1;
 cps:=round(bytes/seconds);
 str(cps,s);
 thruput:=s+' cps';
end;

{**************************************************************************}

function a_upload(filename:string):boolean;

type
 acknak=record
  blknum:longint;
  status:char;
  crc:word;
 end; 
 
const
 sa=sizeof(acknak); 

var
 loop,remainder:word;
 filelen,blocks,bytes:longint;
 buffer:array [1..1024] of byte;
 f:file;
 sbytes:string[10];
 retries,proceed,b:byte;
 
 my:acknak;
 opacket:array [1..sa] of byte absolute my;
 
 his:acknak;
 ipacket:array [1..sa] of byte absolute his;
 
begin
 job:='Uploading   ';
 status;
 a_upload:=false;
 assign(f,filename);
 reset(f,1);
 if ioresult<>0 then begin
  log('! Could not open file '+filename);
  exit;
 end;
 filelen:=filesize(f);
 blocks:=filelen div 1024;
 remainder:=filelen mod 1024;
 if remainder>0 then inc(blocks);
 win(3);
 writeln('Sending   ',filename,', ',filelen,' bytes');
 my.blknum:=1;
 my.crc:=0;
 retries:=0;
 logwin:=3;
 if killdata then fillchar(buffer,1024,'?');
 starttimer;
 repeat
  status;
  win(3);
  if retries=0 then begin
   if not killdata then begin
    if my.blknum=blocks then begin
     fillchar(buffer,1024,0);
     blockread(f,buffer,remainder);
    end else blockread(f,buffer,1024);
   end;
   bytes:=my.blknum*1024;
   str(bytes,sbytes);
   my.crc:=my.blknum;
   crc16(my.crc,buffer,1024);
  end; 

  write(#13'Sending   ',sbytes);

  if charwaiting then begin
   repeat
    b:=auxtb(250);
   until timedout;
  end;
  
  for loop:=1 to sa do sendaux(opacket[loop]);
  for loop:=1 to 1024 do sendaux(buffer[loop]);
  
  while not ((charwaiting) or (retries>9)) do begin
   if escpressed then retries:=10;
  end;
  
  for loop:=1 to sa do ipacket[loop]:=auxtb(1000);
  
  if (my.crc=his.crc) and (my.blknum=his.blknum) then begin
   inc(my.blknum);
   retries:=0;
  end else begin
   inc(retries); 
   writeln;
   if my.crc<>his.crc then writeln('* Receiver detected error in data');
   if my.blknum<>his.blknum then writeln('* Receiver detected wrong block');
   writeln('* Resending from '+sbytes);
  end; 
 until (my.blknum>blocks) or escpressed or (retries>9);
 endtimer(bytes);
 if my.blknum>blocks then a_upload:=true;
 close(f);
 writeln;
end;

{**************************************************************************}

function a_download(filename:string;filelen:longint):boolean;

type
 acknak=record
  blknum:longint;
  status:char;
  crc:word;
 end; 
 
const
 sa=sizeof(acknak);
 
var
 loop,remainder,filenum,wait:word;
 blocks,bytes:longint;
 f:file;
 next,sbytes:string[10];
 dir:dirstr;
 name:namestr;
 ext:extstr;
 retries,proceed,b:byte;
 
 my:acknak;
 opacket:array [1..sa] of byte absolute my;
 
 his:acknak;
 ipacket:array [1..sa] of byte absolute his;
 
begin
 job:='Downloading ';
 status;
 a_download:=false;
 fsplit(fexpand(filename),dir,name,ext);
 if exist(filename) then begin
  filenum:=1;
  repeat
   str(filenum:3,next);
   for loop:=1 to 2 do if next[loop]=' ' then next[loop]:=ext[succ(loop)];
   filename:=dir+name+'.'+next;
   inc(filenum);
  until not(exist(filename)) or (filenum=1000);
 end;
 filename:=fexpand(filename);
 assign(f,filename);
 rewrite(f,1);
 if ioresult<>0 then begin
  log('! Could not open file '+filename);
  exit;
 end;
 allocbuf;
 xferfile:=filename;
 blocks:=filelen div 1024;
 remainder:=filelen mod 1024;
 if remainder>0 then inc(blocks);
 my.blknum:=1;
 retries:=0;
 logwin:=3;
 win(3);
 writeln('Receiving ',filename,', ',filelen,' bytes');
 starttimer;
 repeat
  status;
  win(3);
  bytes:=my.blknum*1024;
  str(bytes,sbytes);
  write(#13'Receiving ',sbytes);

  repeat
   if escpressed then retries:=10;
  until charwaiting or (retries>9);
  
  for loop:=1 to sa do ipacket[loop]:=auxtb(1000);
  wait:=0;
  loop:=bufpos;
  repeat
   while charwaiting do begin
    buf^[loop]:=getaux;
    inc(loop);
   end;
   if not charwaiting then begin
    delay(10);
    inc(wait);
   end else wait:=0;
  until (loop=bufpos+1024) or (escpressed) or (wait>100);
   
  my.crc:=my.blknum;
  crc16(my.crc,buf^[bufpos],1024);
  
  if his.blknum=pred(my.blknum) then begin
   my.blknum:=his.blknum;
   my.crc:=his.crc;
   writeln('* Ignoring duplicate block');
  end; 
  
  if charwaiting then begin
   repeat
    b:=auxtb(250);
   until timedout; 
  end;
  for loop:=1 to sa do sendaux(opacket[loop]);
  
  if (my.crc=his.crc) and (my.blknum=his.blknum) then begin
   inc(my.blknum);
   retries:=0;
   if killdata then fillchar(buf^[bufpos],1024,'?');
   inc(bufpos,1024);
   if bufpos>=buflen then begin
    blockwrite(f,buf^,buflen);
    bufpos:=0;
   end;
  end else begin
   inc(retries);
   writeln;
   if my.crc<>his.crc then writeln('* Detected error in data');
   if my.blknum<>his.blknum then writeln('* Wrong block detected');
   writeln('* Requesting resend from '+sbytes);
  end;

 until (my.blknum>blocks) or escpressed or (retries>9);
 endtimer(bytes);
 if my.blknum>blocks then a_download:=true;
 blockwrite(f,buf^,bufpos);
 reset(f);
 if filelen<filesize(f) then begin
  seek(f,filelen);
  truncate(f);
 end; 
 close(f);
 writeln;
 mem_free(bufseg);
end;
