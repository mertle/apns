{This version and all that are comms-compatible with v2.15 must accept
 both IBM-packed and Unix format dates. The next non-comms-compatible
 version will use Unix-style dates only}

function polled:result;

var
 loop,outer,times:word;
 s:string;
 bytestran:longint;
 dt:datetime;
 nextfile:searchrec;
 handshake,mine:hspacket;
 transfer:txpacket;
 proceed:boolean;
 response:byte;

begin

{Initialise what variables we can, not knowing who the caller is yet}

 polled:=fail;
 log('');

 fillchar(mine,sizeof(mine),0);
 mine.sender:=setup.site;
 
{Be prepared to wait absolutely yonks for STANDBY from the caller}

 win(3);
 writeln('Waiting for APNS caller to commence communications... ');
 loop:=1;
 laststr:='';
 repeat
  job:='Listening   ';
  status;
  delay(100);
  while charwaiting do receive;
  inc(loop);
  proceed:=pos('STANDBY',laststr)>0;
 until (proceed) or (loop=1200) or escpressed;
 if wherex>1 then writeln;
 
 if not proceed then begin
  log('! Initial APNS handshake failed');
  hangup;
  exit;
 end;
 auxwrite('READY');
 log('  Handshake initiated'); 
 
{Get sender's identity and number of files}

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
 
 poller:=handshake.sender;

 if (handshake.sender=setup.site) or (handshake.receiver<>setup.site) or
    (handshake.password<>setup.password) then begin
  log('! Security violation');
  hangup;
  exit;
 end;
 
 polled:=partial;
 if handshake.unixvalid then unix2dos(handshake.unixtime+(setup.gmtdiff*60),dt)
  else unpacktime(handshake.ldate,dt);
 if ((handshake.unixvalid) or (handshake.timevalid)) and
    (not setup.blockrtc) then begin
  setdate(dt.year,dt.month,dt.day);
  settime(dt.hour,dt.min,dt.sec,99);
 end;
 
{Receive sender's files}

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

 polled:=oneway;

{Now we can scan for files to send to the caller}

 job:='Find Files  ';
 status;

 mine.receiver:=handshake.sender;

 findfirst(setup.updir+'\*.*',0,nextfile);
 while doserror=0 do begin
  if (pos('-ALL',nextfile.name)=5) or (pos(handshake.sender,nextfile.name)=5)
   then inc(mine.files);
  findnext(nextfile);
 end;

 if handshake.nopickup then begin
  mine.files:=0;
  log('  Caller requested that no files be sent');
 end;
 
{Send this information to the caller}
{Note that Mine.UnixValid & Mine.TimeValid are false currently. For future use} 

 times:=0;
 repeat
  gettime(dt.hour,dt.min,dt.sec,loop);
  getdate(dt.year,dt.month,dt.day,loop);
  mine.unixtime:=dos2unix(dt);
  sendbytes(mine,sizeof(mine));
  proceed:=(auxtb(2000)=AP_ACK);
  inc(times);
  status;
 until proceed or (times=10) or escpressed;
 if not proceed then begin
  log('! Outbound identity transfer failed');
  hangup;
  exit;
 end;
 str(mine.files,s);
 log('  We have '+s+' files to send');

{Now send each of the files to the caller, if he's still there}

 findfirst(setup.updir+'\*.*',0,nextfile);
 for outer:=1 to mine.files do begin
  while (pos('-ALL',nextfile.name)<>5) and
        (pos(handshake.sender,nextfile.name)<>5) do findnext(nextfile);
  transfer:=nextfile;
  times:=0;
  repeat
   sendbytes(transfer,sizeof(transfer));
   proceed:=auxtb(2000)=AP_ACK;
   inc(times);
   status;
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

 log('  Successful session');
 polled:=success;
 hangup;
end;
