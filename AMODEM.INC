const
 retrymax=10;
 errormax=10;

var
 start:longint;

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
 hour,min,sec,hun:word;
 code:integer;
 finish,diff:longint;
 percent,cps,baud,seconds:real;
 s:string;

begin
 gettime(hour,min,sec,hun);
 finish:=converttime(hour,min,sec,hun);
 if finish<start then inc(finish,8640000);
 diff:=finish-start;
 seconds:=diff/100;
 val(curspeed,baud,code);
 baud:=baud/10;
 cps:=bytes/seconds;
 percent:=(cps/baud)*100;
 str(percent:1:2,s);
 thruput:=s+'%';
end;

{**************************************************************************}

procedure purge;

var
 response:byte;

begin
 repeat
  while charwaiting do response:=getaux;
  delay(100);
 until not charwaiting;
end;

{**************************************************************************}

function X_Upload(filename:string;size:word;var bytes:longint):boolean;

type
 buftype=array [0..1023] of byte;

var
 sectornum:integer;
 filelen,blocks,remainder,blks_read:longint;
 using_crc,resend:boolean;
 checksum,b,start,errors,response,counter:byte;
 loop,crc:word;
 x_buffer:buftype;
 f:file;
 s:string;

begin
 thruput:='0.00%';
 x_upload:=false;
 if size=128 then start:=SOH else start:=STX;
 writeln;
 assign(f,filename);
 reset(f,1);
 if ioresult<>0 then log(logfile,_Error_Read+filename);
 filelen:=filesize(f);
 blocks:=filelen div size;
 remainder:=filelen mod size;
 writeln(fexpand(filename)+space,succ(blocks),_Blocks_Of,size,_Bytes+lf);
 sectornum:=1;
 blks_read:=0;
 errors:=0;
 bytes:=0;
 using_crc:=true;

 s:='  Receiver selected ';
 if using_crc then s:=s+'CRC-16' else s:=s+'Checksum';
 log(logfile,s);
 starttimer;
 repeat
  counter:=0;
  if (blks_read=blocks) and (size=1024) then begin
   blks_read:=blks_read shl 3;
   size:=128;
   start:=SOH;
   blocks:=filelen div size;
   remainder:=filelen mod size;
  end;
  if blks_read=blocks then begin
   fillchar(x_buffer,1024,nul);
   blockread(f,x_buffer,remainder);
  end else begin
   blockread(f,x_buffer,size);
   inc(blks_read);
  end;
  write(cr+'Sending: ',bytes,' (',size:4,')');
  resend:=false;
  str(bytes,s);
  repeat
   if resend then begin
    writeln;
    log(logfile,'* Resending from byte '+s);
    purge;
   end;
   sending:=true;
   status;
   checksum:=0;
   crc:=0;
   sendaux(start);
   sendaux(sectornum);
   sendaux(255-sectornum);

   {New Feature 13/11/91, Pre-Init CRC with block number}

   crc16(checksum,crc,sectornum);

   for loop:=0 to pred(size) do begin
    sendaux(x_buffer[loop]);
    crc16(checksum,crc,x_buffer[loop]);
   end;
   if charwaiting then purge;
   if using_crc then begin
    sendaux(hi(crc));
    sendaux(lo(crc));
   end else sendaux(checksum);
   sending:=false;
   status;
   response:=auxtb(1000);
   write(' Got: ',response:3,#13);
   inc(counter);
   resend:=true;
  until (response=ACK) or (counter>=retrymax) or abort;
  if abort then counter:=retrymax;
  status;
  inc(sectornum);
  inc(bytes,size);
  if sectornum>255 then sectornum:=0;
 until (eof(f)) or (counter>=retrymax);

 if counter>=retrymax then begin
  writeln;
  log(logfile,'! No ACK on byte '+s);
 end else begin
  counter:=0;
  repeat
   sendaux(EOT);
   inc(counter);
  until (auxtb(1000)=ACK) or (counter=retrymax);
  if counter>=retrymax then begin
   writeln;
   log(logfile,'! No ACK on EOT, at byte '+s)
  end else begin
   writeln;
   log(logfile,'  Transfer complete');
   x_upload:=true;
  end;
  endtimer(filelen);
 end;
 close(f);
end;

{**************************************************************************}

function X_Download(filename:string;var bytes:longint):boolean;

type
 buftype=array [0..1023] of byte;

const
 cancel=#24#24#24#24#24#24#24#24#8#8#8#8#8#8#8#8;

var
 sectornum,sectorcurrent,sectorcomp:integer;
 errorflag:boolean;
 pass_chk,using_crc,firstblock:boolean;
 f:file;
 x_buffer:buftype;
 loop,size,crc,hiscrc,number:word;
 errors,first,checksum,position:byte;
 next:string[3];
 s:string;
 dir:dirstr;
 name:namestr;
 ext:extstr;

begin
 thruput:='0.00%';
 x_download:=false;
 writeln;
 sectornum:=0;
 errors:=0;
 bytes:=0;
 errorflag:=false;
 firstblock:=true;

 fsplit(fexpand(filename),dir,name,ext);
 if exist(filename) then begin
  number:=0;
  repeat
   str(number:3,next);
   for loop:=1 to 2 do if next[loop]=' ' then next[loop]:='0';
   filename:=dir+name+'.'+next;
   inc(number);
  until not(exist(filename));
 end;
 log(logfile,'  '+fexpand(filename));
 assign(f,filename);
 rewrite(f,1);
 if ioresult<>0 then begin
  log(logfile,'! Error creating file');
  exit;
 end;
 starttimer;
 repeat
  str(bytes,s);
  abort:=false;
  timedout:=false;
  repeat
   first:=auxtb(1000);
  until (first in [SOH,STX,EOT]) or timedout or abort;
  if timedout then begin
   writeln;
   log(logfile,'! Timed-out waiting for byte '+s);
  end else if abort then begin
   writeln;
   log(logfile,'! Transfer aborted');
   close(f);
   exit;
  end else begin
   size:=127;
   if first=STX then begin
    size:=1023;
    first:=SOH;
   end;
   if first=SOH then begin
    firstblock:=false;
    checksum:=0;
    crc:=0;
    errorflag:=false;
    status;
    sectorcurrent:=auxtb(1000);                     {real sector number}
    sectorcomp:=auxtb(1000);                        {+ inverse of above}

    {New Feature 13/11/91, Pre-Init CRC with block number}

    crc16(checksum,crc,sectorcurrent);

    for loop:=0 to size do begin
     x_buffer[loop]:=auxtb(1000);
     crc16(checksum,crc,x_buffer[loop]);
    end;

    if using_crc then begin
     hiscrc:=auxtb(1000)+(auxtb(1000) shl 8);
     pass_chk:=(hiscrc=crc);
    end else pass_chk:=(checksum=auxtb(1000));

    if not pass_chk then begin
     writeln;
     log(logfile,'! Data error at byte '+s);
     errorflag:=true;
    end;

    if sectorcurrent+sectorcomp<>255 then begin
     writeln;
     log(logfile,'! Block number failed CRC at byte '+s);
     pass_chk:=false;
     errorflag:=true;
    end else if sectorcurrent=sectornum then begin
     writeln;
     log(logfile,'! Ignoring duplicate block at byte '+s);
     pass_chk:=false;
     errorflag:=false;
     sendaux(ACK);
     timedout:=false;
    end else if sectorcurrent<>succ(sectornum) then begin
     writeln;
     log(logfile,'! Fatal loss of synchronisation at byte '+s);
     pass_chk:=false;
     errorflag:=true;
     errors:=errormax;
    end;

    if pass_chk then begin
     sendaux(ACK);
     blockwrite(f,x_buffer,succ(size));
     status;
     errors:=0;
     timedout:=false;
     sectornum:=sectorcurrent;
     if sectornum=255 then sectornum:=-1;
     inc(bytes,succ(size));
     write(cr+'Receiving: ',bytes,' bytes (',succ(size):4,')');
    end;
   end;
   if errorflag then begin
    purge;
    sendaux(NAK);
    inc(errors);
    timedout:=false;
   end;
  end;
 until (first=EOT) or timedout or (errors>=errormax) or abort;
 if abort then errors:=errormax;
 if (first=EOT) and (errors<errormax) then begin
  sendaux(ACK);
  writeln;
  log(logfile,'  Transfer complete');
  endtimer(bytes);
  x_download:=true;
 end else begin
  writeln;
  log(logfile,'! Transfer aborted');
  rawsend(cancel);
 end;
 close(f);
end;
