{$A+,B-,D-,E-,F-,G+,I-,L-,N-,O-,R-,S-,V-,X-}
{$M 1024,0,0}

Unit Comms;

{ ------------------------------------------------------- }
{ Unit containing procedures and functions for interrupt  }
{ driven control of the asynchronous RS232 port.          }
{                                                         }
{  Supports comm ports 1, 2, 3 and 4 (IBM)                }
{           comm ports       3 and 4 (Kortex) as 5 and 6  }
{           comm ports       3 and 4 (Nokia)  as 7 and 8  }
{                                                         }
{  All at 300, 1200, 2400, 9600, 19.2, 38.4, 76.8, 115.2  }
{                                                         }
{  Last modifed: Oct 1992, 16550-AFN Fifo buffer support  }
{                Oct 1992, Restore old interrupt mask bit }
{ ------------------------------------------------------- }

INTERFACE

USES      Crt, Dos;

TYPE

          COMPORT = Record
           Base : Word;
           IRQ  : Byte;
           Int  : Byte;
          End;

CONST
          COMDATA : Array [1..8] Of ComPort = ((Base:$3F8;IRQ:$EF;Int:$C),
                                               (Base:$2F8;IRQ:$F7;Int:$B),
                                               (Base:$3E8;IRQ:$EF;Int:$C),
                                               (Base:$2E8;IRQ:$F7;Int:$B),
                                               (Base:$370;IRQ:$F7;Int:$B),
                                               (Base:$270;IRQ:$F7;Int:$B),
                                               (Base:$3E8;IRQ:$DF;Int:$D),
                                               (Base:$3E8;IRQ:$FB;Int:$A));

          { Protocol Constants }

          NUL = #$00;       SOH = $01;        STX = $02;
          ETX = $03;        EOT = $04;        ENQ = $05;
          ACK = $06;        BEL = #$07;       BS  = #$08;
          TAB = #$09;       LF  = #$0A;       CR  = #$0D;
          NAK = $15;        CAN = $18;        ESC = #$1B;
          DEL = #$7F;       SYN = 22;

          CTRLZ = $1A;      CEE = $43;        SPACE = ' ';

          { Serial Port Registers }

          IER         = 1;               { Interrupt enable }
          IIR         = 2;               { Interrupt ID }
          FCR         = 2;               { FIFO control register }
          LCR         = 3;               { Line control register  }
          MCR         = 4;               { Modem control register }
          LSR         = 5;               { Line status register }
          MSR         = 6;               { Modem status register }
          SCR         = 7;               { Scratch register }
         {DLL         = 0;}              { Divisor latch low }
          DLH         = 1;               { Divisor latch high }

          { Status values for Line Status Register }

          RCVRDY      = $01;           { Data ready flag }
          OVRERR      = $02;           { Overrun error }
          PRTYERR     = $04;           { Parity error }
          FRMERR      = $08;           { Framing error }
          BRKINT      = $10;           { Break interrupt }
          XMTRDY      = $20;           { Transmit register empty }
          XMTRSR      = $40;           { Tx shift register empty }

          { Status values for Modem Status Register }

          DCTS        = $01;           { Delta CTS }
          DDSR        = $02;           { Delta DSR }
          TERI        = $04;           { Trailing Edge Ring Indicator }
          DDCD        = $08;           { Delta DCD }
          CTS         = $10;           { Clear To Send }
          DSR         = $20;           { Data Set Ready }
          RI          = $40;           { Ring Indicator }
          CD          = $80;           { Carrier Detect }

          { Control values for Modem Control Register }

          DTR         = $01;           { Data Terminal Ready }
          RTS         = $02;           { Request To Send }
          OUT1        = $04;           { Hayes Reset }
          OUT2        = $08;           { Enable Interrupts }
          LOOPBIT     = $10;           { Loopback bit }

          IMR         = $21;
          ICR         = $20;
          EOI         = $20;           { PIC - End of interrupt }
          RX_MASK     = 7;
          RX_ID       = 4;

          IRQ3        = $0F7;          { Interrupt request lines }
          IRQ4        = $0EF;

          MC_INT      = 8;
          RX_INT      = 1;

          NO_PAR      = 0;             { parity settings }
          EV_PAR      = 1;
          OD_PAR      = 2;
          MA_PAR      = 3;
          SP_PAR      = 4;

          BufSize     = 8192;          { input buffer - 8K }

          TimedOut: BOOLEAN = FALSE;   { Used by AuxTB and AuxTC }
          NulModem: BOOLEAN = FALSE;   { True if direct connection }
          Aborting: BOOLEAN = FALSE;   { User termination request }
          Running : BOOLEAN = FALSE;   { True after startup }

VAR       PortBase :  Word;                           { port base address }
          IntoBase :  Word;                           { port IIR address  }
          PortNum  :  Word;
          IntNo    :  Byte;
          PortBuf  :  Array[0..BufSize] of byte;      { input buffer }
          StartBuf,
          EndBuf   :  Integer;
          OldVect  :  Pointer;
          OldIMR   :  Byte;

          
procedure SetPort( PortNo  : Byte;          {Configure com port}
                   Baudrate: Longint;
                   Parity,
                   Length,
                   StopBits : Integer);
procedure OpenComms;                        {Install interrupt routine}
procedure CloseComms;                       {Restore interrupt routine}
procedure RaiseDTR;                         {Raise data terminal ready}
procedure LowerDTR;                         {Lower data terminal ready}
function CharWaiting :  Boolean;            {True if byte waiting in buffer}
function GetAux :  Byte;                    {Returns next byte from buffer}
procedure SendAux(b : Byte);                {Send single byte to com port}
procedure AuxWrite(S:String);               {Send a string to the com port}
procedure RawSend(S:String);                {Send a string byte by byte}
function CarrierDetect :  Boolean;          {True if carrier detected}
function Abort:Boolean;                     {Gets and resets abort flag}
function AuxTB(Time :  Word) :  Byte;       {Aux input with time-limit}
function SetFifo:Boolean;                   {Activate 16550-AFN Fifos}


IMPLEMENTATION

{ --------------------------------------------------- }
{ This is the the new asynchronous interrupt routine. }
{ --------------------------------------------------- }

procedure asyncint; interrupt;

begin
 inline($FA);                          { CLI - Disable interrupts }
 if ((port[intobase] and RX_MASK)=RX_ID) then begin
  portbuf[endbuf]:=port[portbase];
  inc(endbuf);
  endbuf:=endbuf mod bufsize;
 end;
 port[ICR]:=EOI;
 inline($FB);                          { STI - restart interrupts }
end;


{ --------------------------------------------- }
{ Enable the new asynchronous interrupt driver. }
{ --------------------------------------------- }

procedure interruptenable;

var       
 c:byte;

begin
 inline($FA);                         { cli - disable interrupts }
 intno:=comdata[portnum].int;

 getintvec(intno,oldvect);            { save the old interrupt contents }
 setintvec(intno,@asyncint);          { now point to our routine }

 c:=port[portbase+MCR] or mc_int;
 port[portbase+MCR]:=c;
 port[portbase+IER]:=rx_int;

 OldIMR:=port[IMR] and not(comdata[portnum].irq);
 c:=port[IMR] and comdata[portnum].irq;
 port[IMR]:=c;

 inline($FB);                         { sti - restart interrupts }
end;


{ ------------------------------------------------------------- }
{ Return control to the original asynchronous interrupt driver. }
{ ------------------------------------------------------------- }

PROCEDURE InterruptDisable;

VAR
 c:byte;

BEGIN

 c:=port[IMR] or OldIMR;

 Inline( $FA );                    { CLI - Disable interrupts }
 Port[IMR] := c;
 Port[PortBase + IER] := 0;
 c := Port[PortBase + MCR] and (NOT MC_INT);
 Port[PortBase + MCR] := c;
 Port[PortBase + FCR] := 0;

 SetIntVec(IntNo, OldVect);         { restore the old interrupt contents }
 Inline( $FB );                     { STI - restart interrupts }
END;


{ --------------------------- }
{ Set up the port parameters. }
{ --------------------------- }

PROCEDURE SetPort( PortNo  : Byte;
                   Baudrate: Longint;
                   Parity,
                   Length,
                   StopBits: Integer);

VAR
 c,temp:byte;
 divisor:word;

BEGIN

 PortNum := PortNo;
 PortBase := ComData[PortNum].Base;
 IntoBase := PortBase + 2;

 CASE BaudRate OF
  19200 :  Divisor := 6;
   9600 :  Divisor := 12;
   4800 :  Divisor := 24;
   2400 :  Divisor := 48;
   1200 :  Divisor := 96;
    600 :  Divisor := 192;
    300 :  Divisor := 384;
   else;
 END;
 If BaudRate=115200 then Divisor:=1;
 If BaudRate= 76800 then Divisor:=2;
 If BaudRate= 38400 then Divisor:=3;

 Inline($FA);                          { CLI - Disable interrupts }
 c := Port[PortBase + LCR];
 Port[PortBase + LCR] := (c or $80);     {Access BRDL and BRDH regs}
 Port[PortBase {DLL}] := lo(Divisor);
 Port[PortBase + DLH] := lo(Divisor SHR 8);
 Port[PortBase + LCR] := c;              {Back to THR / RDR regs}

 Temp := Length - 5;
 IF StopBits = 2 THEN Temp := Temp or 4;
 CASE Parity OF
  NO_PAR :{ Temp := Temp or $00};
  OD_PAR :  Temp := Temp or $08;
  EV_PAR :  Temp := Temp or $18;
  MA_PAR :  Temp := Temp or $28;
  SP_PAR :  Temp := Temp or $38;
 END;
 Port[PortBase + LCR] := Temp;
 Inline($FB);                          { STI - restart interrupts }
END;


{ -------------------------------- }
{ Open the port for communicatons. }
{ -------------------------------- }

procedure opencomms;

var
 c:byte;

begin
 startbuf:=0;
 endbuf:=0;
 running:=true;
 inline($FA);                          { CLI - Disable interrupts }

 interruptenable;
 c:=port[portbase+MCR] or DTR or RTS;
 port[portbase+MCR]:=c;

 inline($FB);                          { STI - restart interrupts }
end;                


{ --------------------------------------- }
{ Shut down the comms port when finished. }
{ --------------------------------------- }

procedure closecomms;

begin
 inline($FA);                          { CLI - Disable interrupts }
 port[portbase+MCR]:=0;
 interruptdisable;
 inline($FB);                          { STI - restart interrupts }
 running:=false;
end;


{ -------------------------------- }
{ Set 'Data Terminal Ready' to on. }
{ -------------------------------- }

procedure raisedtr;

var
 c:byte;

begin
 c:=port[portbase+MCR] or DTR;
 inline($FA);                          { CLI - disable interrupts }
 port[portbase+MCR]:=c;
 inline($FB);                          { STI - restart interrupts }
end;


{ --------------------------------- }
{ Set 'Data Terminal Ready' to off. }
{ --------------------------------- }

procedure lowerdtr;

var
 c:byte;

begin
 c:=port[portbase+MCR];
 if (c and DTR)=DTR then begin
  dec(c);                           { DTR = 1, thus dec = no DTR}
  inline($FA);                      { CLI - disable interrupts }
  port[portbase+MCR]:=c;
  inline($FB);                      { STI - restart interrupts }
 end;
end;


{ ------------------------------------------------------------- }
{ Returns true if character(s) are waiting in the input buffer. }
{ ------------------------------------------------------------- }

function charwaiting:boolean;

begin
 charwaiting:=(endbuf<>startbuf);
end;


{ ------------------------------------------------------- }
{ Returns the next character waiting in the input buffer. }
{ ------------------------------------------------------- }

function getaux:byte;

begin
 getaux:=portbuf[startbuf];
 startbuf:=succ(startbuf) mod bufsize;    { wrap-around buffer if full }
end;


{ ------------------------------------------------------------------- }
{ This procedure is called by AuxWrite and actually does the sending. }
{ ------------------------------------------------------------------- }

procedure sendaux(b:byte);

var
 timeout:word;

begin
 inline($FA);                          { CLI - disable interrupts }
 timeout:=$FFFF;
 port[portbase+mcr]:=OUT2 or DTR or RTS;
 while ((port[portbase+msr] and CTS)=0) and (timeout>0) do
  dec(timeout);
 timeout:=$FFFF;
 while ((port[portbase+LSR] and DSR)=0) and (timeout>0) do
  dec(timeout);
 port[portbase]:=b;
 inline($FB);                          { sti - restart interrupts }
end;


{ ---------------------------------------- }
{ Send the given string to the RS232 port. }
{ ---------------------------------------- }

procedure auxwrite(s:string);

var
 loop,psn:byte;

begin
 psn:=1;
 while psn<length(s) do begin
  if s[psn]='^' then begin
   delete(s,psn,1);
   s[psn]:=chr(ord(upcase(s[psn]))-64);
  end;
  inc(psn);
 end;
 
 for loop:=1 to length(s) do begin
  case s[loop] of
   '|':sendaux(13);                 { carriage return }
   '~':delay(500);                  { 1/2 second pause }
   else sendaux(ord(s[loop]));
  end;
  delay(1);
 end;
end;


{ ---------------------------------------- }
{ Sends the given string to the modem raw. }
{ ---------------------------------------- }

procedure rawsend(s:string);

var
 loop:byte;

begin
 for loop:=1 to length(s) do sendaux(ord(s[loop]));
end;


{ --------------------------------------------------- }
{ Returns true if a Carrier Detect signal is present. }
{ --------------------------------------------------- }

function carrierdetect:boolean;

begin
 carrierdetect := running and ((port[portbase + MSR] and CD = CD) or nulmodem);
end;


{ --------------------------------------- }
{ Allows main program to get abort status }
{ --------------------------------------- }

function abort:boolean;

begin
 abort:=aborting;
 aborting:=false;
end;


{ ----------------------------------------- }
{ Allows user to escape during timed inputs }
{ ----------------------------------------- }

procedure testabort;

var
 c:char;

begin
 c:=#0;
 if keypressed then c:=readkey;
 aborting:=(c=#27);
end;


{ ------------------------------------------ }
{ Reads byte from the com port with timeout. }
{ ------------------------------------------ }

function auxtb(time:word):byte;

begin
 timedout:=false;
 time:=round(time/10);
 if charwaiting then auxtb:=getaux else begin
  repeat
   delay(10);
   testabort;
   dec(time);
  until aborting or (time=0) or charwaiting;
  if charwaiting then auxtb:=getaux else begin
   auxtb:=255;
   timedout:=true;
  end;
 end;
end;

{ ------------------------------- }
{ Activate 16550-AFN Fifo buffers }
{ ------------------------------- }

function SetFifo:Boolean;

begin
 port[portbase+FCR]:=$01;
 SetFifo:=(port[portbase+FCR] and $C0)=$C0;
end;

end.  { of Comms unit }
