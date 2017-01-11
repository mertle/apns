var
 current,temp:dialentry;
 dialfile:file of dialentry;

const
 last:longint=0;

procedure sendbytes(p:dptr;l:word);

var
 b,chksum:byte;
 loop,crc:word;

begin
 crc:=0;
 for loop:=1 to l do begin
  sendaux(p^[loop]);
  crc16(chksum,crc,p^[loop]);
 end;
 sendaux(hi(crc));
 sendaux(lo(crc));
end;

function recvbytes(p:dptr;l:word):boolean;

var
 chksum:byte;
 loop,crc,his:word;

begin
 crc:=0;
 for loop:=1 to l do begin
  p^[loop]:=auxtb(1000);
  crc16(chksum,crc,p^[loop]);
 end;
 his:=auxtb(1000)+(auxtb(1000) shl 8);
 recvbytes:=(his=crc);
end;

function maketime(addmins:byte):longint;

var
 dt:datetime;
 temp:word;
 result:longint;

begin
 gettime(dt.hour,dt.min,dt.sec,temp);
 getdate(dt.year,dt.month,dt.day,temp);
 inc(dt.min,addmins);
 if dt.min>59 then begin
  dec(dt.min,60);
  inc(dt.hour);
 end;
 if dt.hour>23 then begin
  dec(dt.hour,24);
  inc(dt.day);
 end;
 if dt.day>31 then begin
  dec(dt.day,31);
  inc(dt.month);
 end;
 if dt.month>12 then begin
  dec(dt.month,12);
  inc(dt.year);
 end;
 packtime(dt,result);
 maketime:=result;
end;

{$I amodem.inc}

{$I polling.inc}

{$I polled.inc}

procedure wait;

var
 retcode:result;
 loop:byte;
 c:char;
 s:string;

begin
 write(#10'Auto-Answer Window starts at ',setup.waitstart,':00');
 writeln(' ESC exits, SPACE for DOS shell'#10);
 repeat
  c:=#0;
  repeat
   status;
  until (hour in [setup.waitstart..23,0..setup.waitfinish]) or keypressed;
  if keypressed then c:=readkey;
  if c=space then run('');
 until (hour in [setup.waitstart..23,0..setup.waitfinish]) or (c=#27);

 if c=#27 then begin
  initialise;
  exit;
 end;

 delay(1000);
 for loop:=1 to length(setup.cmdanswer) do begin
  auxwrite(setup.cmdanswer[loop]);
  while charwaiting do write(chr(getaux));
  delay(10);
 end;
 repeat
  write(auxtc(1000));
 until timedout;

 writeln(#10'Waiting for call, ESC exits, SPACE for DOS Shell'#10);

 repeat
  status;
  if carrierdetect then begin
   while charwaiting do begin
    delay(20);
    write(chr(getaux));
   end;
   retcode:=polled;
   log(logfile,timer);
   status;
   if (retcode=success) or (retcode=oneway) then begin
    s:=setup.okwait;
    replace(s,'%SITE',setup.site,false);
    if s<>'' then run(s);
    writeln(#10'Waiting for call, ESC exits, SPACE for DOS Shell'#10);
    if setup.exitafter then hour:=setup.waitfinish;
   end;
  end;
  c:=#0;
  if keypressed then c:=readkey;
  if c=space then run('');
 until (c=#27) or (hour=setup.waitfinish);
 initialise;
 exit;
end;

procedure dial;

var
 loop,outer,number,called,target,now:longint;
 inner:byte;
 send,s,whole,part:string;
 thour,tmin,tsec:word;
 c:char;
 currtime:longint;

begin
 assign(dialfile,homepath+'APNS.FON');
 reset(dialfile);
 if ioresult<>0 then begin
  log(logfile,'! There are no entries in the dialling directory');
  exit;
 end;
 last:=filesize(dialfile);
 number:=0;
 for loop:=0 to pred(last) do begin
  seek(dialfile,loop);
  read(dialfile,current);
  if current.days>6 then begin
   log(logfile,'');
   str(current.days,s);
   log(logfile,'! '+current.name+' (Site '+current.site+') has been unreachable for '+s+' days');
  end else inc(number);
  inc(current.days);
  current.today:=fail;
  current.attempts:=0;
  current.notuntil:=0;
  seek(dialfile,loop);
  write(dialfile,current);
 end;

 {Check for duplicates here, if there are any: number:=0 and message}

 for outer:=0 to last-2 do begin
  seek(dialfile,outer);
  read(dialfile,temp);
  for loop:=succ(outer) to pred(last) do begin
   read(dialfile,current);
   if current.site=temp.site then begin
    log(logfile,'! Duplicate site ID '+temp.site+' in the dialling directory');
    number:=0;
   end;
  end;
 end;

 if number=0 then begin
  log(logfile,'! There are no diallable entries in the dialling directory');
  exit;
 end;

 writeln('ESC exits, SPACE for DOS Shell, Auto-Dial Window starts at ',
         setup.dialstart,':00');
 repeat
  status;
  c:=#0;
  if keypressed then c:=readkey;
  if c=' ' then run('');
 until (hour in [setup.dialstart..23,0..setup.dialfinish]) or (c=ESC);
 if c=ESC then begin
  close(dialfile);
  exit;
 end;
 called:=0;
 repeat
  status;
  for loop:=0 to pred(last) do if hour<>setup.dialfinish then begin
   currtime:=maketime(0);
   seek(dialfile,loop);
   read(dialfile,current);
   if (current.days<8) and (current.today<>success) and
      (currtime>=current.notuntil) and (current.attempts<setup.maxattempts)
   then begin

    repeat
     c:=auxtc(1000);
    until timedout;

    inc(current.attempts);

  {Make this number undiallable for n mins}

    current.notuntil:=maketime(setup.dialpause);
    seek(dialfile,loop);
    write(dialfile,current);
    str(current.attempts,s);
    log(logfile,'');
    log(logfile,'  Dialling '+current.name+' (Site '+current.site+
            ') Attempt '+s);
    writeln;

    send:=current.prefix+current.number+cr;
    for inner:=1 to length(send) do begin
     auxwrite(send[inner]);
     delay(20);
     while charwaiting do write(chr(getaux));
     delay(20);
    end;

    delay(1500);
    while charwaiting do write(chr(getaux));

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
    str(thour:2,whole);
    if whole[1]=' ' then whole[1]:='0';
    str(tmin:2,part);
    if part[1]=' ' then part[1]:='0';
    whole:=whole+':'+part;
    str(tsec:2,part);
    if part[1]=' ' then part[1]:='0';
    whole:=whole+':'+part;
    writeln(#13#10'Dialling until '+whole);
    repeat
     status;
     now:=(hour*3600)+(min*60)+sec;
     if now>target then dec(now,86400);
    until (now=target) or keypressed or carrierdetect or charwaiting;
    writeln('Out of dial loop');
    laststr:='';
    while charwaiting do begin
     delay(20);
     c:=auxtc(1000);
     laststr:=laststr+c;
     delay(20);
    end;
    if laststr<>'' then log(logfile,'  Modem reports '+laststr);

    if carrierdetect then begin
     log(logfile,'  Carrier detected');
     current.today:=polling;
     log(logfile,timer);
     if (current.today=success) or (current.today=oneway) then begin
      current.days:=0;
      inc(called);
      s:=setup.okdial;
      replace(s,'%SITE',current.site,false);
      if s<>'' then run(s);
     end;
     seek(dialfile,loop);
     write(dialfile,current);
     writeln;
    end;

    if keypressed then begin
     sendaux(13);
     writeln;
     delay(1000);
     laststr:='';
     while charwaiting do begin
      delay(20);
      quiet;
      delay(20);
     end;
     log(logfile,'  Modem reports '+laststr);

    end;

   end;
  end;
  status;
  c:=#0;
  if keypressed then c:=readkey;
  if c=ESC then begin
   close(dialfile);
   exit;
  end;
  if c=' ' then run('');
 until (called=number) or (hour=setup.dialfinish);

 log(logfile,'');
 log(logfile,'* Summary');
 log(logfile,'');
 for loop:=0 to pred(last) do begin
  seek(dialfile,loop);
  read(dialfile,current);
  case current.today of
   fail:log(logfile,'! Could not connect with site '+current.site+' '+current.name);
   partial:log(logfile,'! Partial transfer with site '+current.site+' '+current.name);
   oneway:log(logfile,'! One-way transfer with site '+current.site+' '+current.name);
   success:log(logfile,'  Successful transfer with site '+current.site+' '+current.name);
   else;
  end;
 end;
 close(dialfile);
end;
