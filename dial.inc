var
 currsite,temp:dialentry;
 dialfile:file of dialentry;
 xferfile:string;
 sess:string[4];

const
 last:longint=0;
 
{*************************************************************************}

procedure purge;

var
 b:byte;

begin
 job:='Purge Buffer';
 status;
 repeat
  b:=auxtb(500);
 until timedout; 
end; 

{*************************************************************************}

procedure sendbytes(var x;l:word);

var
 p:dptr;
 loop,crc:word;
 b:byte;

begin
 job:='Send Packet ';
 status;
 p:=@x;
 crc:=0;
 for loop:=1 to l do sendaux(p^[loop]);
 crc16(crc,p^,l);
 sendaux(hi(crc));
 sendaux(lo(crc));
end;

{*************************************************************************}

function recvbytes(var x;l:word):boolean;

var
 p:dptr;
 loop,crc,his:word;
 b:byte;

begin
 job:='Recv. Packet';
 status;
 p:=@x;
 crc:=0;
 for loop:=1 to l do p^[loop]:=auxtb(1000);
 crc16(crc,p^,l);
 his:=auxtb(1000)+(auxtb(1000) shl 8);
 recvbytes:=(his=crc);
end;

{*************************************************************************}

function maketime(addsecs:word):longint;

var
 temp:word;
 dt:datetime;

begin
 with dt do begin
  gettime(hour,min,sec,temp);
  getdate(year,month,day,temp);
 end; 
 maketime:=dos2unix(dt)+addsecs;
end;

{*************************************************************************}

function checkoutbound(lookfor:string):longint;

var
 pkts,bytes:longint;
 s:string;
 sr:searchrec;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 srce,dest:string[4];

begin
 pkts:=0;
 bytes:=0;
 win(2);
 findfirst(setup.updir+'\*.*',0,sr);
 while doserror=0 do begin
  if (lookfor='') or (pos(lookfor,sr.name)=5) or (pos('-ALL',sr.name)=5) 
                  or (pos(sess,sr.name)=5) then begin
   if pkts=0 then begin
    write('Checking outbound directory');
    if lookfor<>'' then writeln(' for ',lookfor) else writeln;
   end;
   fsplit(sr.name,dir,name,ext);
   if length(name)<>8 then log('! Misnamed packet: '+sr.name) else begin
    srce:=copy(name,1,4);
    dest:=copy(name,5,4);
    write('From ',srce,' To ',dest);
    if srce=setup.site then write(' (Direct)') else
    if dest=setup.site then write(' (Local) ') else
     write(' (Routed)');
    writeln(' Size: ',sr.size);
    inc(pkts);
    inc(bytes,sr.size);
   end;
  end; 
  findnext(sr);
 end; 
 if pkts>0 then writeln('Number of packets: ',pkts,' totalling ',bytes,' bytes');
 checkoutbound:=pkts;
end;

{*************************************************************************}

function checkinbound:longint;

var
 pkts,bytes:longint;
 s:string;
 sr:searchrec;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 srce,dest:string[4];

begin
 pkts:=0;
 bytes:=0;
 win(2);
 s:=setup.downdir+'\*.*';
 findfirst(s,0,sr);
 while doserror=0 do begin
  if pkts=0 then writeln('Checking inbound directory');
  fsplit(sr.name,dir,name,ext);
  if length(name)<>8 then log('! Misnamed packet: '+sr.name) else begin
   srce:=copy(name,1,4);
   dest:=copy(name,5,4);
   write('From ',srce,' To ',dest);
   if srce=setup.site then write(' (Local) ') else
   if (dest=setup.site) or (dest='-ALL') or (copy(dest,1,2)='-S') then
    write(' (Direct)') else write(' (Routed)');
   writeln(' Size: ',sr.size);
   inc(pkts);
   inc(bytes,sr.size);
  end;
  findnext(sr);
 end;
 if pkts>0 then writeln('Number of packets: ',pkts,' totalling ',bytes,' bytes');
 checkinbound:=pkts;
end;

{*************************************************************************}

procedure split_multi(site:string);

var
 i,o:file;
 sr:searchrec;
 number,bread:word;
 iname,oname,ext:string;

begin
 allocbuf;
 job:='Split -ALLs ';
 findfirst(setup.updir+'\*.*',0,sr);
 while doserror=0 do begin
  status;
  if (pos('-ALL',sr.name)=5) or (pos(sess,sr.name)=5) then begin
   iname:=setup.updir+'\'+sr.name;
   oname:=setup.updir+'\'+copy(sr.name,1,4)+site+'.';
   ext:='000';
   number:=1;
   while (exist(oname+ext)) and (number<1000) do begin
    ext:=itos(number,3);
    inc(number);
   end;
   assign(i,iname);
   reset(i,1);
   assign(o,oname+ext);
   rewrite(o,1);
   if ioresult=0 then begin
    repeat
     blockread(i,buf^,buflen,bread);
     blockwrite(o,buf^,bread);
    until bread<buflen;
    close(i);
    close(o);
   end;
  end; 
  findnext(sr);
 end;
 mem_free(bufseg);
end;

{*************************************************************************}

procedure kill_multi;

var
 f:file;
 sr:searchrec;

begin
 job:='Kill -ALLs  ';
 findfirst(setup.updir+'\*.*',0,sr);
 while doserror=0 do begin
  status;
  if (pos('-ALL',sr.name)=5) or (pos(sess,sr.name)=5) then begin
   assign(f,setup.updir+'\'+sr.name);
   erase(f);
   if ioresult<>0 then beep;
  end; 
  findnext(sr);
 end;
end;

{*************************************************************************}

function nodial:boolean;

begin
 nodial:=false;
 if pos('NO DIALTONE',laststr)>0 then nodial:=true;
 if pos('ERROR',laststr)>0 then nodial:=true;
 if pos('BUSY',laststr)>0 then nodial:=true;
 if pos('NUMBER',laststr)>0 then nodial:=true;
 if pos('NO CARRIER',laststr)>0 then nodial:=true;
end;

{*************************************************************************}

{$I proto.inc}
{$I polling.inc}
{$I polled.inc}

{*************************************************************************}

procedure wait;

var
 packets:longint;
 s:string;
 retcode:result;
 loop,nhour,chour:byte;
 c:char;
 ok:boolean;

begin
 qlog('  Waiting for answer window');
 
 chour:=pred(setup.waitfinish);
 if chour=255 then chour:=23;
 if chour<setup.waitstart then inc(chour,24);

 c:='þ';
 repeat
  if c<>#0 then begin
   delay(500);
   with setup do setport(comport,baud,parity,length,stopbits);
   delay(500);
   if not init(setup.cmdinit) then exit;
   win(2);
   s:=itos(setup.waitstart,2);
   writeln('Waiting to begin auto-answer mode ('+s+':00)');
  end;
  c:=#0;
  job:='Waiting     ';
  status;
  if keypressed then c:=readkey;
  if c='*' then run('');
  
  win(3);
  while charwaiting do begin
   write(chr(getaux));
   delay(md);
  end;
  
  nhour:=hour;
  if nhour<setup.waitstart then inc(nhour,24);

 until (nhour in [setup.waitstart..chour]) or (c=#27);

 if c=#27 then begin
  win(2);
  log('! APNS Wait aborted from the keyboard');
  exit;
 end;

 qlog('  Waiting for a call');
 c:='þ';

 repeat
  if c<>#0 then begin
   hangup;
   delay(500);
   with setup do setport(comport,baud,parity,length,stopbits);
   delay(500);
   if not init(setup.cmdinit) then exit;
   delay(1000);
   if not init(setup.cmdanswer) then exit;
   packets:=checkoutbound('');
   win(2);
   writeln('Waiting for a call');
  end;
  c:=#0;

  win(3);
  while (charwaiting) and (not carrierdetect) do begin
   status;
   write(chr(getaux));
   delay(md);
  end;

  job:='Waiting     ';
  status;

  if carrierdetect and (sitecrc<>6541) then begin
   job:='Answering   ';
   status;
   delay(500);
   win(3);
   
   retcode:=polled;
   job:='Exiting Call';
   status;
   c:='þ'; {Force modem reinit}
   log(timer);
   route;
   if (retcode=success) then begin
    s:=ucase(setup.okwait);
    replace(s,'%SITE',poller,false);
    if s<>'' then begin
     if pos('%FILE',s)>0 then onebyone(setup.downdir,s) else
     run(s);
    end; 
    win(2);
    if exitafter then hour:=setup.waitfinish;
   end;
  end;

  if keypressed then c:=readkey;
  if c='#' then auxwrite('ATA|');
  if c='*' then run('');
  if c='^' then hangup;
  if c='?' then begin
   s:=ucase(setup.okwait);
   replace(s,'%SITE',setup.site,false);
   if s<>'' then begin
    if pos('%FILE',s)>0 then onebyone(setup.downdir,s) else
    run(s);
   end; 
  end;
 until (c=#27) or (hour=setup.waitfinish);
 win(2);
 writeln('Please wait...');
 if c=#27 then qlog('! APNS Wait aborted from the keyboard');
 ok:=init(setup.cmdinit);
 win(2);
 packets:=checkinbound;
 writeln('APNS Wait finished');
 exit;
end;

{*************************************************************************}

procedure dial;

var
 outer,totsites,called,target,now,loopsite:longint;
 send,s:string;
 currtime,packets,deaduntil:longint;
 c:char;
 dialnow,proceed,writeback,display,sentfiles,dead:boolean;
 inner,chour,nhour,cpos:byte;

begin
 deaduntil:=0;
 sentfiles:=false;
 qlog('  Waiting for dialling window');
 job:='Check Nodes ';
 status;
 win(2);
 assign(dialfile,homepath+'APNS.FON');
 reset(dialfile);
 errcheck(' while reading the Node List');
 last:=filesize(dialfile);
 totsites:=0;
 win(2);
 for loopsite:=0 to pred(last) do begin
  status;
  seek(dialfile,loopsite);
  read(dialfile,currsite);
  writeback:=true;
  
  if (currsite.days>6) and (currsite.session=currsession) then begin
   str(currsite.days,s);
   log('! '+currsite.site+' '+currsite.name+' has been unobtainable for '+s+' days');
   writeback:=false;
  end;
   
  if (currsite.control=never) or (currsite.session<>currsession)
   then writeback:=false;
   
  if currsite.number='' then begin
   log('! '+currsite.site+' '+currsite.name+' has no telephone number');
   writeback:=false;
  end; 
  
  if currsite.site='' then begin
   log('! '+currsite.name+' has no site code');
   writeback:=false;
  end;
   
  if writeback then begin
   inc(totsites);
   inc(currsite.days);
   currsite.today:=fail;
   currsite.attempts:=0;
   currsite.notuntil:=0;
   seek(dialfile,loopsite);
   write(dialfile,currsite);
  end; 
 end;

 {Check for duplicates here, if there are any: totsites:=0 and message}

 job:='Security    ';
 status;
 for outer:=0 to pred(last) do begin
  seek(dialfile,outer);
  read(dialfile,temp);
  if temp.site=setup.site then begin
   log('! Duplicate site ID '+setup.site);
   totsites:=0;
  end; 
  for loopsite:=succ(outer) to pred(last) do begin
   status;
   read(dialfile,currsite);
   if currsite.site=temp.site then begin
    log('! Duplicate site ID '+temp.site+' '+currsite.name+' & '+temp.name);
    totsites:=0;
   end;
  end;
 end;

 if totsites=0 then begin
  log('! Cannot dial any of the entries in the nodelist');
  exit;
 end;

 chour:=pred(setup.dialfinish);
 if chour=255 then chour:=23;
 if chour<setup.dialstart then inc(chour,24);

 c:='þ';
 repeat
  if c<>#0 then begin
   with setup do setport(comport,baud,parity,length,stopbits);
   str(setup.baud:6,curspeed);
   if not init(setup.cmdinit) then exit;
   packets:=checkoutbound('');
   win(2);
   s:=itos(setup.dialstart,2);
   writeln('Waiting for auto-dial window to start ('+s+':05)');
  end;
  c:=#0;

  job:='Waiting     ';
  status;

  if keypressed then c:=readkey;
  if c='*' then run('');

  nhour:=hour;
  if nhour<setup.dialstart then inc(nhour,24);
  
  proceed:=nhour in [setup.dialstart..chour];
  if (nhour=chour) and (min<5) then proceed:=false;
  
 until (proceed) or (c=#27);

 if c=ESC then begin
  close(dialfile);
  win(2);
  log('! APNS Dial aborted from the keyboard');
  exit;
 end;

 sess:=itos(succ(currsession),2);
 qlog('  Dialling sites. Session '+sess);
 sess:='-S'+sess;
 called:=0;

 repeat
  job:='Waiting     ';
  status;
  dead:=true;
  for loopsite:=0 to pred(last) do if hour<>setup.dialfinish then begin
   if c<>#0 then begin
    hangup;
    delay(500);
    with setup do setport(comport,baud,parity,length,stopbits);
    delay(500);
    str(setup.baud:6,curspeed);
    if not init(setup.cmdinit) then exit;
    win(2);
    writeln('Waiting to dial');
   end;
   c:=#0;

   currtime:=maketime(0);
   seek(dialfile,loopsite);
   read(dialfile,currsite);
   
   dialnow:=(currsite.days<8);
   if sitecrc=6541 then dialnow:=false;
   if currsite.control=never then dialnow:=false;
   if currsite.session<>currsession then dialnow:=false;
   if currsite.site='' then dialnow:=false;
   if currsite.number='' then dialnow:=false;
   if currsite.today=success then dialnow:=false;
   if currsite.attempts>=setup.maxattempts then dialnow:=false;
   if (dialnow) and (currsite.control<>whensend) then dead:=false;
   if currtime<currsite.notuntil then dialnow:=false;
   if (currsite.control=whensend) and (dialnow) then begin
    packets:=checkoutbound(currsite.site);
    if packets=0 then begin
     dialnow:=false;
     currsite.notuntil:=maketime(setup.dialpause*60);
     seek(dialfile,loopsite);
     write(dialfile,currsite);
    end; 
   end;
   if keypressed then dialnow:=false;
   
   if dialnow then begin
    dead:=false;
    c:='þ';

    {Inc. # of retries and make this number undiallable for n mins}

    inc(currsite.attempts);
    currsite.notuntil:=maketime(setup.dialpause*60);
    seek(dialfile,loopsite);
    write(dialfile,currsite);
    
    job:='Dialling    ';
    status;
    win(2);
    writeln;
    packets:=checkoutbound(currsite.site);
    
    str(currsite.attempts,s);
    writeln(logfile);
    log('  Dialling '+currsite.name+' (Site '+currsite.site+') Attempt '+s);
    
    with setup do setport(comport,currsite.bips,parity,length,stopbits);
    delay(500);
    str(currsite.bips:6,curspeed);
    purge;
    win(3);
    send:=currsite.prefix+currsite.number+cr;
    laststr:='';
    for inner:=1 to length(send) do begin
     auxwrite(send[inner]);
     delay(md);
     while charwaiting do receive;
     delay(md);
    end;

    status;
    delay(1500);
    while charwaiting do receive;

    target:=maketime(setup.dialtime);
    win(2);
    job:='Awaiting    ';
    repeat
     status;
     now:=maketime(0);
    until (now>=target) or keypressed or carrierdetect or charwaiting or nodial;
    write('Finished dialling:');
    if nodial then write(' Modem Abort;');
    if now=target then write(' Time Up;');
    if keypressed then write(' Key Pressed;');
    if carrierdetect then write(' Carrier Detect;');
    if charwaiting then write(' Modem Response;'); 
    writeln;
    
    if charwaiting then begin
     laststr:='';
     win(3);
     while (charwaiting) and (not keypressed) do begin
      receive;
      delay(md);
      status;
     end;
     if laststr<>'' then log('  Modem reports '+laststr);
     laststr:='';
    end; 
    
    if not carrierdetect then begin
     if nodial     then qlog('  Modem would not dial number');
     if keypressed then qlog('  Dial interrupted from keyboard');
     win(3);
     writeln;
    end;

    if (carrierdetect) and (not keypressed) then begin
     log('  Carrier detected');
     currsite.today:=polling;
     log(timer);
     route;
     if (currsite.today=success) or (currsite.today=oneway) then begin
      currsite.days:=0;
      sentfiles:=true;
      if currsite.today=success then inc(called);
      s:=ucase(setup.okdial);
      replace(s,'%SITE',currsite.site,false);
      if s<>'' then begin
       if pos('%FILE',s)>0 then onebyone(setup.updir,s) else
       run(s);
      end; 
     end;
     seek(dialfile,loopsite);
     write(dialfile,currsite);
    end;

    if currsite.attempts>=setup.maxattempts then inc(called);
     
    if (keypressed) or (now=target) then begin
     job:='Aborting    ';
     status;
     win(3);
     sendaux(13);
     delay(1000);
     laststr:='';
     while charwaiting do begin
      delay(md);
      c:=chr(auxtb(1000));
      write(c);
      if (c<>#10) and (c<>#13) then laststr:=laststr+c;
      delay(md);
     end;
     if laststr<>'' then log('  Modem reports '+laststr);
     while keypressed do c:=readkey;
     c:='þ';
    end;

   end;
  end;
  
  currtime:=maketime(0);
  if currtime<deaduntil then dead:=false else 
  if (dead) and (called<totsites) and (hour<>setup.dialfinish) then begin
   job:='Finished?   ';
   loopsite:=0;
   repeat
    status;
    seek(dialfile,loopsite);
    read(dialfile,currsite);
    if currsite.control=whensend then begin
     packets:=checkoutbound(currsite.site);
     if packets>0 then dead:=false;
    end; 
    inc(loopsite);
   until (loopsite=last) or (not dead);
   deaduntil:=maketime(setup.dialpause*60); 
  end;
  
  status;
  if keypressed then c:=readkey;
  if c=ESC then begin
   win(2);
   log('! APNS Dial aborted from the keyboard');
   hour:=setup.dialfinish;
  end; 
  if c='*' then run('');
  
 until (dead) or (called>=totsites) or (hour=setup.dialfinish);
 
 packets:=checkinbound;
 job:='Call Summary';
 writeln(logfile);
 log('* Summary for '+date);
 writeln(logfile);
 for loopsite:=0 to pred(last) do begin
  status;
  writeback:=false;
  display:=true;
  seek(dialfile,loopsite);
  read(dialfile,currsite);
  delay(100);
  if (currsite.today=fail) and (currsite.control=whensend) then begin
   if currsite.days>0 then dec(currsite.days);
   writeback:=true;
  end; 
  if (currsite.control=never) or (currsite.session<>currsession)
   then display:=false;
  if (sentfiles) and ((currsite.today=fail) or (currsite.today=partial)) then
   split_multi(currsite.site);
  if display then case currsite.today of
   fail   :log('! Did not connect with site '    +currsite.site+' '+currsite.name);
   partial:log('! Handshake only with site '     +currsite.site+' '+currsite.name);
   oneway :log('! One-way transfer with site '   +currsite.site+' '+currsite.name);
   success:log('  Successful transfer with site '+currsite.site+' '+currsite.name);
   else;
  end;
  if writeback then begin
   seek(dialfile,loopsite);
   write(dialfile,currsite);
  end;
 end;
 close(dialfile);
 if sentfiles then kill_multi;
end;
