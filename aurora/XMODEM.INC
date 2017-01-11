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
  response:=auxtb(35);
 until timedout;
 timedout:=false;
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
 x_upload:=true;
 if size=128 then start:=SOH else start:=STX;
 writeln;
 assign(f,filename);
 reset(f,1);
 if ioresult<>0 then log(_Error_Read+filename);
 filelen:=filesize(f);
 blocks:=filelen div size;
 remainder:=filelen mod size;
 writeln(fexpand(filename)+space,succ(blocks),_Blocks_Of,size,_Bytes+lf);
 sectornum:=1;
 blks_read:=0;
 errors:=0;
 bytes:=0;
 repeat
  repeat               {receiver driven}
   b:=auxtb(10000);    {initial 10 seconds}
   if Abort or (not carrierdetect) then begin
    timedout:=true;
    errors:=10;
   end;
  until (b in [NAK,CEE,CAN]) or timedout;
  if (b=CAN) and (auxtb(1000)=CAN) then errors:=10;
  using_crc:=(b=CEE);
  if timedout then inc(errors);
 until (errors=10) or (b in [NAK,CEE]);
 if errors=10 then begin
  close(f);
  log(_Transfer_Aborted);
  x_upload:=false;
  exit;
 end;
 s:='  Receiver selected ';
 if using_crc then s:=s+'CRC-16' else s:=s+'Checksum';
 log(s);
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
    log('* Resending from byte '+s);
   end;
   sending:=true;
   status;
   checksum:=0;
   crc:=0;
   purge;
   sendaux(start);
   sendaux(sectornum);
   sendaux(255-sectornum);
   for loop:=0 to pred(size) do begin
    sendaux(x_buffer[loop]);
    crc16(checksum,crc,x_buffer[loop]);
   end;
   if using_crc then begin
    sendaux(hi(crc));
    sendaux(lo(crc));
   end else sendaux(checksum);
   inc(counter);
   sending:=false;
   status;
   resend:=true;
   response:=auxtb(1000);
  until (response=ACK) or (counter=retrymax) or abort;
  if abort then counter:=retrymax;
  status;
  inc(sectornum);
  inc(bytes,size);
  if sectornum>255 then sectornum:=0;
 until (eof(f)) or (counter=retrymax);

 if counter=retrymax then begin
  writeln;
  log('! No ACK on byte '+s);
  x_upload:=false;
 end else begin
  counter:=0;
  repeat
   sendaux(EOT);
   inc(counter);
  until (auxtb(1000)=ACK) or (counter=retrymax);
  if counter=retrymax then begin
   writeln;
   log('! No ACK on EOT, at byte '+s)
  end else begin
   writeln;
   log('  Transfer complete');
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
 x_download:=true;
 writeln;
 sectornum:=0;
 errors:=0;
 bytes:=0;
 errorflag:=false;
 firstblock:=true;
 loop:=1;
 repeat
  sendaux(CEE); {with 'C' attempt to initiate CRC mode}
  inc(loop);
  first:=auxtb(1000);
 until (loop>3) or (first in [SOH,STX,EOT]) or abort;
 case first of
  SOH:begin
       using_crc:=true;
       log('  CRC-16 128b mode');
      end;
  STX:begin
       using_crc:=true;
       log('  CRC-16 1K mode');
      end;
  EOT:begin
       log('! Transfer aborted');
       x_download:=false;
       exit;
      end;
  else begin
        using_crc:=false;
        loop:=1;
        repeat
         sendaux(NAK); {attempt to initiate checksum mode}
         first:=auxtb(1000);
         inc(loop);
         if (loop>15) then abort:=true;
         if Abort then begin
          first:=EOT;
          rawsend(cancel);
         end;
        until first in [SOH,STX,EOT];
        case first of
         SOH:log('  Checksum 128b mode');
         STX:log('  Checksum 1K mode');
         EOT:begin
              log('! Transfer aborted');
              x_download:=false;
              exit;
             end;
        end;
       end;
 end;
 fsplit(fexpand(filename),dir,name,ext);
 if exist(filename) then begin
  number:=0;
  repeat
   next:=itos(number,3);
   filename:=dir+name+'.'+next;
   inc(number);
  until not(exist(filename));
 end;
 log('  '+fexpand(filename));
 assign(f,filename);
 rewrite(f,1);
 if ioresult<>0 then begin
  log('! Error creating file');
  x_download:=false;
  exit;
 end;
 starttimer;
 repeat
  str(bytes,s);
  abort:=false;
  if not firstblock then repeat
   first:=auxtb(10000);
  until (first in [SOH,STX,EOT]) or timedout or abort;
  if timedout then begin
   writeln;
   log('! Timed-out waiting for byte '+s);
  end;
  if abort then begin
   writeln;
   log('! Transfer aborted');
   x_download:=false;
   close(f);
   exit;
  end;
  size:=127;
  if first=STX then begin
   size:=1023;
   first:=SOH;
  end;
  if first = SOH then begin
   firstblock:=false;
   checksum:=0;
   crc:=0;
   errorflag:=false;
   status;
   sectorcurrent:=auxtb(1000);                     {real sector number}
   sectorcomp:=auxtb(1000);                        {+ inverse of above}
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
    log('! Data error at byte '+s);
    errorflag:=true;
   end;
   if sectorcurrent+sectorcomp<>255 then begin
    writeln;
    log('! Block number garbled at byte '+s);
    pass_chk:=false;
    errorflag:=true;
   end;
   if sectorcurrent=succ(sectornum) then begin
   end else
   if sectorcurrent=sectornum then begin
    writeln;
    log('! Ignoring duplicate block at byte '+s);
    pass_chk:=false;
    errorflag:=false;
    sendaux(ACK);
   end else begin
    writeln;
    log('! Fatal loss of synchronisation at byte '+s);
    pass_chk:=false;
    errorflag:=true;
    errors:=errormax;
   end;
   if pass_chk then begin
    blockwrite(f,x_buffer,succ(size));
    sendaux(ACK);
    status;
    errors:=0;
    sectornum:=sectorcurrent;
    if sectornum=255 then sectornum:=-1;
    inc(bytes,succ(size));
    write(cr+'Receiving: ',bytes,' bytes (',succ(size):4,')');
   end;
  end;
  if errorflag then begin
   inc(errors);
   sendaux(NAK);
  end;
 until (first=EOT) or timedout or (errors>=errormax) or abort;
 if abort then errors:=errormax;
 if (first=EOT) and (errors<errormax) then begin
  sendaux(ACK);
  writeln;
  log('  Transfer complete');
  endtimer(bytes);
 end else begin
  writeln;
  log('! Transfer aborted');
  rawsend(cancel);
  x_download:=false;
 end;
 close(f);
end;
