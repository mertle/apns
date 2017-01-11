const
 version='2.15b';
 hexstr:string[16]='0123456789ABCDEF';
 yesno:array [false..true] of string[3]=('No ','Yes');
 monocols:array [1..7] of byte=(7,0,0,7,0,7,0);

type
 result=(fail,partial,oneway,success);
 dialmode=(everyday,whensend,never);
 sitecode=string[4];
 schedentry=record
  name:string[60];
  okonday:array [0..6] of boolean;
  weekno:byte;
  actdate:string[8];
  command:string[60];
  lastrun:word;
  priority:string[4];
  onceonly:boolean;
  country:byte;
  holiday:boolean;
  other:array [1..107] of byte;
 end;

 dialentry=record
  name:string[40];
  number:string[40];
  prefix:string[40];
  site:sitecode;
  days:byte;
  today:result;
  attempts:word;
  notuntil:longint;
  bips:longint;
  sendtime:boolean;
  control:dialmode;
  session:byte;
  other:array [1..113] of byte;
 end;
 
 modementry=record
  name:string[40];
  cmdinit:string[40];
  cmdhangup:string[40];
  cmdpredial:string[40];
  cmdanswer:string[40];
 end;

 hspacket=record
  sender:sitecode;
  receiver:sitecode;
  files:word;
  ldate:longint;
  timevalid:boolean;
  password:string[40];
  nopickup:boolean;
  unixtime:longint;
  unixvalid:byte;
  revision:word;
  newstuff:array [1..194] of byte;
 end;

 txpacket=searchrec;

 dummy=array [1..1200] of byte;
 dptr=^dummy;

 frametype=array [1..8] of char;

 config=record
  winstyle:byte;
  sound:boolean;
  fclr,bclr:byte;        {main screen colours}
  wfclr,wbclr,wsclr:byte;{window colours}
  hfclr,hbclr:byte;      {highlight bar colours}
  comport:byte;
  baud:longint;
  parity,length,         {modem defaults}
  stopbits:integer;
  directvideo,snow:boolean;   {monitor options}
  nulmodem:boolean;
  cmdinit:string[40];
  cmdhangup:string[40];
  cmdpredial:string[40];
  cmdanswer:string[40];
  updir:string[40];
  downdir:string[40];
  dialtime:byte;
  dialpause:byte;
  maxattempts:byte;
  dialstart:byte;
  dialfinish:byte;
  waitstart:byte;
  waitfinish:byte;
  exitafter:boolean;
  mnptime:byte;
  site:sitecode;
  okdial:string[70];
  okwait:string[70];
  password:string[40];
  com5:comport;
  modemname:string[40];
  usefifos:boolean;
  gmtdiff:integer;
  blockrtc:boolean;
  otherstuff:array [1..507] of byte;
  crc:word;
 end;
 checkconf=array [1..sizeof(config)-2] of byte;

const
 frame:array [0..9] of frametype=('        ','ÚÄ¿³ÀÙ´Ã','ÉÍ»ºÈ¼µÆ','ÕÍ¸³Ô¾µÆ',
                                  'ÖÄ·ºÓ½´Ã','ÚÄ¿³ÀÙ¿Ú','ÉÍ»ºÈ¼','ÕÍ¸³Ô¾',
                                  'ÖÄ·ºÓ½®¯','+-+|++[]');
                                  
 setup:config=
 (winstyle:4;
  sound:true;
  fclr:cyan;
  bclr:black;
  wfclr:lightgray;
  wbclr:blue;
  wsclr:lightgreen;
  hfclr:black;
  hbclr:cyan;
  comport:2;
  baud:2400;
  parity:0;
  length:8;
  stopbits:1;
  directvideo:true;
  snow:false;
  nulmodem:false;
  cmdinit:'ATZ|~~~AT&C1&D2|';
  cmdhangup:'~~~+++~~~ATH0|';
  cmdpredial:'ATDT';
  cmdanswer:'ATS0=1|';
  updir:'C:\APNS\SEND';
  downdir:'C:\APNS\RECV';
  dialtime:55;
  dialpause:5;
  maxattempts:6;
  dialstart:23;
  dialfinish:7;
  waitstart:23;
  waitfinish:7;
  exitafter:false;
  mnptime:6;
  site:'0000';
  okdial:'TIDYOUT.BAT %SITE';
  okwait:'TIDYIN.BAT %SITE';
  password:'';
  com5:(Base:$370;IRQ:$F7;Int:$C);
  modemname:'APNS Standard Modem';
  usefifos:false;
  gmtdiff:0;
  blockrtc:false);

 AP_ACK=$AA;
 AP_NAK=$55;

var
 security:checkconf absolute setup;
