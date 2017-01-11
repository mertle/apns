const
 version='1.12à';
 onoff:array [false..true] of string[2]=('ff','n');
 zsig='**'#24;
 monocols:array [1..7] of byte=(7,0,0,7,7,7,0);

type
 frametype=array [1..8] of char;
 emtype=(ansi,avatar,teletype);   {others must go between ansi and teletype}
 config=record
         winstyle:byte;
         sound:boolean;
         fclr,bclr:byte;         {main screen colours}
         wfclr,wbclr,wsclr:byte; {window colours}
         hfclr,hbclr:byte;       {highlight bar colours}
         emu:emtype;             {default emulation}
         comport:byte;
         baud:longint;
         parity,length,          {modem defaults}
         stopbits:integer;
         direct,snow:boolean;    {monitor options}
         nulmodem:boolean;
         cmdinit:string[40];
         cmdhangup:string[40];
         cmdpredial:string[40];
         cmdanswer:string[40];
         updir:string[40];
         downdir:string[40];
         defecho:boolean;
         deflinefeed:boolean;
         deflights:boolean;
         abortdial:string[70];
         dialtime:byte;
         dialpause:byte;
         logon:string[40];
         beep:string[20];
         ansiavatar:boolean;
         caller:string[40];
         location:string[40];
         lockdte:boolean;
         zmodauto:boolean;
         registration:longint;
        end;

const
 setup:config=(winstyle:1;
               sound:true;
               fclr:cyan;
               bclr:black;
               wfclr:white;
               wbclr:blue;
               wsclr:lightgreen;
               hfclr:black;
               hbclr:cyan;
               emu:avatar;
               comport:1;
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
               updir:'';
               downdir:'';
               defecho:false;
               deflinefeed:false;
               deflights:true;
               abortdial:'NO CARRIER,BUSY';
               dialtime:55;
               dialpause:5;
               logon:'MLL8O4ABGO3GO4D';
               beep:'O4L8C';
               ansiavatar:true;
               caller:'';
               location:'';
               lockdte:false;
               zmodauto:false;
               registration:0);

type
 dialentry=record
            name:string[40];
            number:string[40];
            prefix:string[40];
            caller:string[40];
            password:string[40];
            script:string[8];
            datlen:byte;
            parity:byte;
            stopbits:byte;
            bips:longint;
            linefeed:boolean;
            echo:boolean;
            iemsi:boolean;
            iemsifunc:string[20];
            emu:emtype;
            firstcall:longint;
            lastcall:longint;
            totalcalls:word;
           end;
const
 bpsrate:array [1..9] of longint=(300,1200,2400,4800,9600,19200,38400,76800,115200);
 parsetting:array [0..4] of string[5]=('None','Even','Odd','Mark','Space');
 frame:array [0..9] of frametype=('        ','ÚÄ¿³ÀÙ´Ã','ÉÍ»ºÈ¼¹Ì','ÕÍ¸³Ô¾µÆ',
                                  'ÖÄ·ºÓ½¶Ç','ÚÄ¿³ÀÙ®¯','ÉÍ»ºÈ¼','ÕÍ¸³Ô¾',
                                  'ÖÄ·ºÓ½®¯','+-+|++[]');
 
