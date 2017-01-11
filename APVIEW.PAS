{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,0}
program apview;

uses crt,dos,sound;

const
 realfile=$27;

type
 apc=record
  filecrc:word;
  attr:byte;
  time:longint;
  size:longint;
  name:string[12];
 end;
 ss=string[4];

const
 crc_table : array [0..255] of word = (

  $0000,$1021,$2042,$3063,$4084,$50A5,$60C6,$70E7,$8108,$9129,$A14A,$B16B,
  $C18C,$D1AD,$E1CE,$F1EF,$1231,$0210,$3273,$2252,$52B5,$4294,$72F7,$62D6,
  $9339,$8318,$B37B,$A35A,$D3BD,$C39C,$F3FF,$E3DE,$2462,$3443,$0420,$1401,
  $64E6,$74C7,$44A4,$5485,$A56A,$B54B,$8528,$9509,$E5EE,$F5CF,$C5AC,$D58D,
  $3653,$2672,$1611,$0630,$76D7,$66F6,$5695,$46B4,$B75B,$A77A,$9719,$8738,
  $F7DF,$E7FE,$D79D,$C7BC,$48C4,$58E5,$6886,$78A7,$0840,$1861,$2802,$3823,
  $C9CC,$D9ED,$E98E,$F9AF,$8948,$9969,$A90A,$B92B,$5AF5,$4AD4,$7AB7,$6A96,
  $1A71,$0A50,$3A33,$2A12,$DBFD,$CBDC,$FBBF,$EB9E,$9B79,$8B58,$BB3B,$AB1A,
  $6CA6,$7C87,$4CE4,$5CC5,$2C22,$3C03,$0C60,$1C41,$EDAE,$FD8F,$CDEC,$DDCD,
  $AD2A,$BD0B,$8D68,$9D49,$7E97,$6EB6,$5ED5,$4EF4,$3E13,$2E32,$1E51,$0E70,
  $FF9F,$EFBE,$DFDD,$CFFC,$BF1B,$AF3A,$9F59,$8F78,$9188,$81A9,$B1CA,$A1EB,
  $D10C,$C12D,$F14E,$E16F,$1080,$00A1,$30C2,$20E3,$5004,$4025,$7046,$6067,
  $83B9,$9398,$A3FB,$B3DA,$C33D,$D31C,$E37F,$F35E,$02B1,$1290,$22F3,$32D2,
  $4235,$5214,$6277,$7256,$B5EA,$A5CB,$95A8,$8589,$F56E,$E54F,$D52C,$C50D,
  $34E2,$24C3,$14A0,$0481,$7466,$6447,$5424,$4405,$A7DB,$B7FA,$8799,$97B8,
  $E75F,$F77E,$C71D,$D73C,$26D3,$36F2,$0691,$16B0,$6657,$7676,$4615,$5634,
  $D94C,$C96D,$F90E,$E92F,$99C8,$89E9,$B98A,$A9AB,$5844,$4865,$7806,$6827,
  $18C0,$08E1,$3882,$28A3,$CB7D,$DB5C,$EB3F,$FB1E,$8BF9,$9BD8,$ABBB,$BB9A,
  $4A75,$5A54,$6A37,$7A16,$0AF1,$1AD0,$2AB3,$3A92,$FD2E,$ED0F,$DD6C,$CD4D,
  $BDAA,$AD8B,$9DE8,$8DC9,$7C26,$6C07,$5C64,$4C45,$3CA2,$2C83,$1CE0,$0CC1,
  $EF1F,$FF3E,$CF5D,$DF7C,$AF9B,$BFBA,$8FD9,$9FF8,$6E17,$7E36,$4E55,$5E74,
  $2E93,$3EB2,$0ED1,$1EF0);

var
 sr:searchrec;
 mr:apc;
 infile:file of apc;
 ifname,param,s,outline:string;
 crc,loop:word;
 inner,outer,checksum,b:byte;
 buffer:array [1..50000] of byte;
 f:text;
 dir:dirstr;
 name:namestr;
 ext:extstr;
 bytesread:word;
 ioerror:integer;
 dt:datetime;
 nofiles,nobytes:longint;
 fast:boolean;
 
{**************************************************************************} 

function pad(w:word):ss;

var
 temp:ss;

begin
 str(w:2,temp);
 if temp[1]=' ' then temp[1]:='0';
 pad:=temp;
end;

{**************************************************************************} 

function hex(w:word):ss;

const
 hs:array [0..15] of char='0123456789ABCDEF';

begin
 hex:=hs[hi(w) div 16]+hs[hi(w) mod 16]+hs[lo(w) div 16]+hs[lo(w) mod 16];
end;

{**************************************************************************} 

var
 sticky:byte;

begin
 checksnow:=false;
 textattr:=7;
 clrscr;
 fast:=false;
 writeln(#10' ApView - ''FootPrint'' File View / Print Utility v1.20 (c) 1992 Luckyasset Ltd');
 writeln;

 if paramcount<1 then begin
  writeln('Usage: ApView <datafile>');
  exit;
 end;

 ifname:=paramstr(1);
 ifname:=fexpand(ifname);

 assign(infile,ifname);
 reset(infile);
 if ioresult<>0 then begin
  writeln('Could not access ',ifname);
  exit;
 end;
 
 param:=ucase(paramstr(2));
 assign(f,param);
 rewrite(f);
 if ioresult<>0 then begin
  writeln('Could not access ',param);
  exit;
 end;

 writeln('Processing: ',ifname);
 writeln;
 writeln('  File-Name      Size    Attr.     Date      Time     CRC');
 writeln('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');

 nofiles:=0;
 nobytes:=0;
 window(1,8,80,25);
 clrscr;
 repeat
  read(infile,mr);
  move(mr.attr,sr.attr,22);
  inc(nofiles);
  inc(nobytes,sr.size);
  write(sr.name:12);
  gotoxy(13,wherey);
  write(sr.size:10,'  ');

  s:='RHSVDA';
  b:=1;
  for inner:=1 to 6 do begin
   if sr.attr and b<>b then s[inner]:='ú';
   b:=b shl 1;
  end;
  write(s,'  ');

  unpacktime(sr.time,dt);
  with dt do write(pad(day),'/',pad(month),'/',pad(year),' ',pad(hour),':',
   pad(min),':',pad(sec),'  ');
  writeln(hex(mr.filecrc),'h');
 until eof(infile);
 writeln;
 close(infile);
 window(1,4,80,25);
 clrscr;
 writeln('Processed ',nofiles,' files, totalling ',nobytes,' bytes.');
end.
