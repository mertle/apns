const
 version='1.12';
type
 result=(fail,partial,oneway,success);
 sitecode=string[4];
 schedentry=record
  comment:string[60];
  okonday:array [0..6] of boolean;
  weekno:byte;
  actdate:string[8];
  command:string[60];
  lastrun:word;
  priority:string[4];
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
 end;
 hspacket=record
  sender:sitecode;
  receiver:sitecode;
  files:word;
  hour,min,sec,hun,year,month,day:word;
  timevalid:boolean;
  password:string[40];
  newpass:boolean;
  nopickup:boolean;
  vercode:longint;
 end;
 txpacket=searchrec;
 dummy=array [1..1200] of byte;
 dptr=^dummy;
 frametype=array [1..8] of char;
 config=record
       winstyle:byte;
       sound:boolean;
       fclr,bclr:byte;        {main screen colours}
       wfclr,wbclr:byte;      {window colours}
       hfclr,hbclr:byte;      {highlight bar colours}
       comport:byte;
       baud:longint;
       parity,length,         {modem defaults}
       stopbits:integer;
       direct,snow:boolean;   {monitor options}
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
       crc:word;
      end;
 checkconf=array [1..sizeof(config)] of byte;

const
 frame:array [0..9] of frametype=('        ','ÚÄ¿³ÀÙ´Ã','ÉÍ»ºÈ¼¹Ì','ÕÍ¸³Ô¾µÆ',
                                  'ÖÄ·ºÓ½¶Ç','°°°°°°°°','±±±±±±±±','²²²²²²²²',
                                  'ôÄô³õõ´Ã','+-+|++[]');
 setup:config=(winstyle:4;
               sound:true;
               fclr:cyan;
               bclr:black;
               wfclr:lightgray;
               wbclr:blue;
               hfclr:black;
               hbclr:cyan;
               comport:3;
               baud:2400;
               parity:0;
               length:8;
               stopbits:1;
               direct:true;
               snow:false;
               nulmodem:false;
               cmdinit:'ATZ|~~~AT S0=0 S7=59 V1 X1|';
               cmdhangup:'~~+++~~~ATH0|';
               cmdpredial:'ATDT';
               cmdanswer:'ATS0=1|';
               updir:'C:\APNS\SEND';
               downdir:'C:\APNS\RECV';
               dialtime:55;
               dialpause:5;
               maxattempts:6;
               dialstart:20;
               dialfinish:8;
               waitstart:20;
               waitfinish:8;
               exitafter:false;
               mnptime:6;
               site:'0000';
               okdial:'TIDYOUT.BAT %SITE';
               okwait:'TIDYIN.BAT';
               password:'MIDAS');
 AP_ACK=$AA;
 AP_NAK=$55;

var
 security:checkconf absolute setup;
