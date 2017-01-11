{For the time being, this version uses both methods of sending the time, 
 in IBM packed and Unix time formats. The next version that is not comms- 
 compatible with v2.15 will have the Unix (timezoned) format method only}

function polling:result;

var
 outer,loop,times:word;
 s:string;
 bytestran:longint;
 dt:datetime;
 handshake,mine:hspacket;
 transfer:txpacket;
 nextfile:searchrec;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 response:byte;
 proceed:boolean;

begin

{Initialise all variables}

 job:='Find Files  ';
 status;

 polling:=fail;

 fillchar(mine,sizeof(mine),0);

 mine.sender:=setup.site;
 mine.receiver:=currsite.site;
 mine.password:=setup.password;
 mine.timevalid:=currsite.sendtime;
 mine.unixvalid:=currsite.sendtime;

{Get number of files to transmit}

 findfirst(setup.updir+'\*.*',0,nextfile);
 while doserror=0 do begin
  fsplit(fexpand(nextfile.name),dir,name,ext);
  if (pos('-ALL',nextfile.name)=5) or (pos(currsite.site,nextfile.name)=5)
   then inc(mine.files);
  findnext(nextfile);
 end;
 
 if currsite.today=oneway then begin
  log('  Files have already been sent to this site');
  mine.files:=0;
 end; 
 
{We can afford to wait a bit}

 job:='Synchronise ';
 status;
 win(3);
 repeat
  status;
  response:=auxtb(2000);
  write(chr(response));
 until timedout or escpressed;
 writeln;  
 if not timedout then begin
  log('! Initial APNS handshake failed');
  hangup;
  exit;
 end; 
 
{Synchronise}

 win(3);
 times:=1;
 laststr:='';
 repeat
  job:='Sending Wake';
  status;
  writeln('Sending APNS wake-up sequence (',times,' of 10)...');
  auxwrite('STANDBY');
  loop:=1;
  repeat
   status;
   delay(100);
   while charwaiting do receive;
   inc(loop);
   proceed:=pos('READY',laststr)>0;
  until proceed or (loop>50) or escpressed;
  if wherex>1 then writeln;
  inc(times);
 until (proceed) or (times>10) or escpressed; 
 
 if not proceed then begin
  log('! Initial APNS handshake failed');
  hangup;
  exit;
 end;
 log('  Handshake initiated');
 
{Send our APNS identity information}

 times:=0;
 repeat
  gettime(dt.hour,dt.min,dt.sec,loop);
  getdate(dt.year,dt.month,dt.day,loop);
  packtime(dt,mine.ldate); 
  mine.unixtime:=dos2unix(dt)-(setup.gmtdiff*60);
  status;
  sendbytes(mine,sizeof(mine));
  proceed:=(auxtb(2000)=AP_ACK);
  inc(times);
 until proceed or (times=10) or escpressed;
 if not proceed then begin
  log('! Outbound identity transfer failed');
  hangup;
  exit;
 end;
 str(mine.files,s);
 if mine.files>0 then log('  We have '+s+' files to send');

 polling:=partial;

{Send our files, assuming other end does not drop due to security violation}

 findfirst(setup.updir+'\*.*',0,nextfile);
 for outer:=1 to mine.files do begin
  while (pos('-ALL',nextfile.name)<>5) and
        (pos(currsite.site,nextfile.name)<>5) do findnext(nextfile);
  transfer:=nextfile;
  times:=0;
  repeat
   status;
   sendbytes(transfer,sizeof(transfer));
   proceed:=auxtb(2000)=AP_ACK;
   inc(times);
  until proceed or (times=10) or escpressed;
  if not proceed then begin
   log('! Outbound file info transfer failed');
   hangup;
   exit;
  end;
  if not(a_upload(setup.updir+'\'+transfer.name)) then begin
   log('! Upload of '+transfer.name+' failed');
   hangup;
   exit;
  end;
  str(transfer.size,s);
  log('  Outbound: '+transfer.name+' '+s+' bytes. '+thruput);
  findnext(nextfile);
 end;

{Get polled site's handshake information}

 times:=0;
 repeat
  proceed:=recvbytes(handshake,sizeof(handshake));
  if not proceed then sendaux(AP_NAK);
  inc(times);
  status;
 until proceed or (times=10) or escpressed;
 if not proceed then begin
  log('! Inbound identity transfer failed');
  hangup;
  exit;
 end;
 sendaux(AP_ACK);
 str(handshake.files,s);
 log('  Connected to '+handshake.sender+' who has '+s+' files to send');

 if (handshake.receiver<>setup.site) or (handshake.sender<>currsite.site)
 then begin
  log('! Security violation');
  hangup;
  exit;
 end;
 
 polling:=oneway;

{Receive polled site's files}

 for outer:=1 to handshake.files do begin
  times:=0;
  repeat
   status;
   proceed:=recvbytes(transfer,sizeof(transfer));
   if not proceed then sendaux(AP_NAK);
   inc(times);
  until proceed or (times=10) or escpressed;
  if not proceed then begin
   log('! Inbound file info transfer failed');
   hangup;
   exit;
  end;
  sendaux(AP_ACK);
  bytestran:=transfer.size;
  if not(a_download(setup.downdir+'\'+transfer.name,bytestran)) then begin
   log('! Download of '+transfer.name+' failed');
   hangup;
   exit;
  end;
  str(transfer.size,s);
  log('  Inbound : '+transfer.name+' '+s+' bytes. '+thruput);
  setfiletime(xferfile,transfer.time);
 end;

 polling:=success;
 log('  Successful session');
 hangup;
end;
