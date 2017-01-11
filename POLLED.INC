function polled:result;

var
 response:byte;
 loop,outer:word;
 p:dptr;
 handshake,mine:hspacket;
 transfer:txpacket;
 proceed:boolean;
 times:word;
 nextfile:searchrec;
 s:string;
 bytestran:longint;

begin

{Initialise what variables we can, not knowing who the caller is yet}

 polled:=fail;
 log(logfile,'');
 log(logfile,_Session_Beginning+time+_On_The+date);

 mine.sender:=setup.site;
 mine.files:=0;
 with mine do begin
  gettime(hour,min,sec,hun);
  getdate(year,month,day,loop);
  timevalid:=true;
 end;
 mine.nopickup:=false;
 mine.vercode:=0;

{Delay to bypass MNP train}

 writeln;
 for loop:=1 to setup.mnptime*100 do begin
  delay(10);
  write(#13,_Delay,loop/100:1:2);
  while charwaiting do response:=getaux;
 end;
 writeln(#10);

{Wait for Caller's ENQ and send a SYN in return}

 times:=0;
 response:=0;
 repeat
  response:=auxtb(1000);
  if response=ENQ then sendaux(SYN);
  inc(times);
  write('.');
  status;
 until (response=ENQ) or (times=10) or (not carrierdetect);
 writeln;
 if response<>ENQ then begin
  log(logfile,_No_Handshake);
  hangup(false);
  exit;
 end;
 log(logfile,_Got_Handshake);

{Get sender's identity and number of files}

 p:=addr(handshake);
 times:=0;
 repeat
  proceed:=recvbytes(p,sizeof(handshake));
  if not proceed then sendaux(AP_NAK);
  inc(times);
  status;
 until proceed or (times=10) or (not carrierdetect);
 if not proceed then begin
  log(logfile,_No_Identity_In);
  hangup(false);
  exit;
 end;
 sendaux(AP_ACK);
 str(handshake.files,s);
 log(logfile,_Connected_With+handshake.sender+_Who_Has+S+_Files_To_Send);

 if (handshake.sender=setup.site) or (handshake.receiver<>setup.site) then begin
  log(logfile,_security_violation);
  hangup(false);
  exit;
 end;

 polled:=partial;

{Receive sender's files}

 p:=addr(transfer);
 for outer:=1 to handshake.files do begin
  times:=0;
  repeat
   status;
   proceed:=recvbytes(p,sizeof(transfer));
   if not proceed then sendaux(AP_NAK);
   inc(times);
  until proceed or (times=10) or (not carrierdetect);
  if not proceed then begin
   log(logfile,_No_Fileinfo_In);
   hangup(false);
   exit;
  end;
  sendaux(AP_ACK);
  bytestran:=transfer.size;
  purge;
  if not(x_download(setup.downdir+'\'+transfer.name,bytestran))
     or (bytestran<transfer.size) then begin
   log(logfile,_Download_Of+transfer.name+_Failed);
   hangup(false);
   exit;
  end;
  str(transfer.size,s);
  log(logfile,_Incoming+transfer.name+' '+s+_Bytes+thruput);
 end;

 polled:=oneway;

{Now we can scan for files to send to the caller}

 mine.receiver:=handshake.sender;

 findfirst(setup.updir+'\*.*',0,nextfile);
 while doserror=0 do begin
  if (pos('-ALL',nextfile.name)=5) or (pos(handshake.sender,nextfile.name)=5)
   then inc(mine.files);
  findnext(nextfile);
 end;

 if handshake.nopickup then begin
  mine.files:=0;
  log(logfile,'  Caller requested that no files be sent');
 end;

{Send ENQ characters until SYN is received}

 times:=0;
 response:=0;
 repeat
  sendaux(ENQ);
  response:=auxtb(1000);
  inc(times);
  write('.');
  status;
 until (response=SYN) or (times=10) or (not carrierdetect);
 writeln;
 if response<>SYN then begin
  log(logfile,_No_Retrain);
  hangup(false);
  exit;
 end;
 log(logfile,_Got_Retrain);

{Send this information to the caller}

 p:=addr(mine);
 times:=0;
 repeat
  purge;
  sendbytes(p,sizeof(mine));
  proceed:=(auxtb(2000)=AP_ACK);
  inc(times);
  status;
 until proceed or (times=10) or (not carrierdetect);
 if not proceed then begin
  log(logfile,_No_Identity_Out);
  hangup(false);
  exit;
 end;
 str(mine.files,s);
 log(logfile,_We_Have+S+_Files_To_Send);

{Now send each of the files to the caller, if he's still there}

 p:=addr(transfer);
 findfirst(setup.updir+'\*.*',0,nextfile);
 for outer:=1 to mine.files do begin
  while (pos('-ALL',nextfile.name)<>5) and
        (pos(handshake.sender,nextfile.name)<>5) do findnext(nextfile);
  transfer:=nextfile;
  times:=0;
  repeat
   purge;
   sendbytes(p,sizeof(transfer));
   proceed:=auxtb(2000)=AP_ACK;
   inc(times);
   status;
  until proceed or (times=10) or (not carrierdetect);
  if not proceed then begin
   log(logfile,_No_Fileinfo_Out);
   hangup(false);
   exit;
  end;
  purge;
  if not(x_upload(setup.updir+'\'+transfer.name,1024,bytestran))
     or (bytestran<transfer.size) then begin
   log(logfile,_Upload_Of+transfer.name+_Failed);
   hangup(false);
   exit;
  end;
  str(transfer.size,s);
  log(logfile,_Outgoing+transfer.name+' '+s+_Bytes+thruput);
  findnext(nextfile);
 end;

 log(logfile,_Successful_Session);
 polled:=success;
 hangup(false);
end;
