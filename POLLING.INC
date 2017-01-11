function polling:result;

var
 response:byte;
 outer,loop:word;
 p:dptr;
 handshake,mine:hspacket;
 transfer:txpacket;
 proceed:boolean;
 times:word;
 nextfile:searchrec;
 s:string;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 bytestran:longint;

begin

{Initialise all variables}

 polling:=fail;
 log(logfile,'');
 log(logfile,_Session_Beginning+time+_on_the+date);
 mine.sender:=setup.site;
 mine.receiver:=current.site;
 mine.files:=0;
 mine.vercode:=0;
 mine.nopickup:=(current.today=oneway);

 if mine.nopickup then log(logfile,'  Files have already been picked up from this site');

 with mine do begin
  gettime(hour,min,sec,hun);
  getdate(year,month,day,loop);
  timevalid:=true;
 end;

{Get number of files to transmit}

 findfirst(setup.updir+'\*.*',0,nextfile);
 while doserror=0 do begin
  fsplit(fexpand(nextfile.name),dir,name,ext);
  if (pos('-ALL',nextfile.name)=5) or (pos(current.site,nextfile.name)=5)
   then inc(mine.files);
  findnext(nextfile);
 end;

{Delay to bypass MNP training}

 writeln;
 for loop:=1 to setup.mnptime*100 do begin
  delay(10);
  write(#13,_delay,loop/100:1:2);
  while charwaiting do response:=getaux;
 end;
 writeln(#10);

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
 if (response<>SYN) or (not carrierdetect) then begin
  log(logfile,_No_Handshake);
  hangup(false);
  exit;
 end;
 log(logfile,_Got_Handshake);

{Send our handshaking information}

 p:=addr(mine);
 times:=0;
 repeat
  write('Sending Identity: ',times,#13);
  status;
  purge;
  sendbytes(p,sizeof(mine));
  proceed:=(auxtb(2000)=AP_ACK);
  inc(times);
 until proceed or (times=10) or (not carrierdetect);
 writeln;
 if not proceed then begin
  log(logfile,_No_Identity_Out);
  hangup(false);
  exit;
 end;
 str(mine.files,s);
 log(logfile,_We_have+s+_Files_To_Send);

 polling:=partial;

{Send our files, assuming other end does not drop due to security violation}

 p:=addr(transfer);
 findfirst(setup.updir+'\*.*',0,nextfile);
 for outer:=1 to mine.files do begin
  while (pos('-ALL',nextfile.name)<>5) and
        (pos(current.site,nextfile.name)<>5) do findnext(nextfile);
  transfer:=nextfile;
  times:=0;
  repeat
   status;
   purge;
   sendbytes(p,sizeof(transfer));
   proceed:=auxtb(2000)=AP_ACK;
   inc(times);
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
  writeln;
  str(transfer.size,s);
  log(logfile,_Outgoing+transfer.name+' '+s+_Bytes+thruput);
  findnext(nextfile);
 end;

{Wait for Site's ENQ and send a SYN in return}

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
  log(logfile,_No_Retrain);
  hangup(false);
  exit;
 end;
 log(logfile,_Got_Retrain);

{Get polled site's handshake information}

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

 if (handshake.receiver<>setup.site) or (handshake.sender<>current.site)
 then begin
  log(logfile,_Security_Violation);
  hangup(false);
  exit;
 end;

 polling:=oneway;

{Receive polled site's files}

 p:=addr(transfer);
 for outer:=1 to handshake.files do begin
  times:=0;
  repeat
   status;
   proceed:=recvbytes(p,sizeof(transfer));
   if not proceed then sendaux(AP_NAK);
   inc(times);
  until proceed or (times=10) or (not carrierdetect);
  if (not proceed) or (not carrierdetect) then begin
   log(logfile,_No_FileInfo_In);
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
  writeln;
  str(transfer.size,s);
  log(logfile,_Incoming+transfer.name+' '+s+_Bytes+thruput);
 end;

 polling:=success;
 log(logfile,_Successful_Session);
 hangup(false);
end;
