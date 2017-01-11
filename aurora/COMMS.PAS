{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-}
{$M 1024,0,655360}

UNIT      Comms;

{ ------------------------------------------------------- }
{ Unit containing procedures and functions for interrupt  }
{ driven control of the asynchronous RS232 port.          }
{                                                         }
{  Supports comm ports 1, 2, 3 and 4 to 115,200 bps       }
{                                                         }
{  Last modifed: December 1991, Line Noise Filtering      }
{ ------------------------------------------------------- }

INTERFACE

USES      Crt, Dos;

CONST     COM1BASE    = $03F8;         { Base port for COM1: IRQ 4}
          COM2BASE    = $02F8;         {               COM2: IRQ 3}
          COM3BASE    = $03E8;         {               COM3: IRQ 4}
          COM4BASE    = $02E8;         {               COM4: IRQ 3}

          { Protocol Constants }

          NUL = #$00;       SOH = $01;        STX = $02;
          ETX = $03;        EOT = $04;        ENQ = $05;
          ACK = $06;        BEL = #$07;       BS  = #$08;
          TAB = #$09;       LF  = #$0A;       CR  = #$0D;
          NAK = $15;        CAN = $18;        ESC = #$1B;
          DEL = #$7F;       SYN = 22;

          CTRLZ = $1A;      CEE = $43;        SPACE = ' ';

          { Serial Port Registers }

          TX          = 0;               { Transmit register }
          RX          = 0;               { Receive register }
          IER         = 1;               { Interrupt enable }
          IIR         = 2;               { Interrupt ID }
          FCR         = 2;               { FIFO control register }
          LCR         = 3;               { Line control register  }
          MCR         = 4;               { Modem control register }
          LSR         = 5;               { Line status register }
          MSR         = 6;               { Modem status register }
          SCR         = 7;               { Scratch register }
          DLL         = 0;               { Divisor latch low }
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
          OUT1        = $04;
          OUT2        = $08;
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

          COM1        = 1;
          COM2        = 2;
          COM3        = 3;
          COM4        = 4;

          NO_PAR      = 0;             { parity settings }
          EV_PAR      = 1;
          OD_PAR      = 2;
          MA_PAR      = 3;
          SP_PAR      = 4;

          BufSize     = 8192;          { input buffer - 8K }

          TimedOut: BOOLEAN = FALSE;   { Used by AuxTB and AuxTC }
          Direct  : BOOLEAN = FALSE;   { True if direct connection }
          Abort   : BOOLEAN = FALSE;   { User termination request }
          Running : BOOLEAN = FALSE;   { True after startup }

VAR       PortBase :  Word;                           { port base address }
          PortBuf  :  Array[0..BufSize] of byte;      { input buffer }
          StartBuf,
          EndBuf   :  Integer;
          OldVect  :  Pointer;


PROCEDURE SetPort( PortNum : Byte;          {Configure com port}
                   Baudrate: Longint;
                   Parity,
                   Length,
                   StopBits :  Integer);
PROCEDURE OpenComms;                        {Install interrupt routine}
PROCEDURE CloseComms;                       {Restore interrupt routine}
PROCEDURE RaiseDTR;                         {Raise data terminal ready}
PROCEDURE LowerDTR;                         {Lower data terminal ready}
FUNCTION CharWaiting :  Boolean;            {True if byte waiting in buffer}
FUNCTION GetAux :  Byte;                    {Returns next byte from buffer}
PROCEDURE SendAux(b : Byte);                {Send single byte to com port}
PROCEDURE AuxWrite(StrToSend :  String);    {Send a string to the com port}
PROCEDURE RawSend(StrToSend : String);      {Send a string byte by byte}
FUNCTION CarrierDetect :  Boolean;          {True if carrier detected}
FUNCTION AuxTB(Time :  Word) :  Byte;       {Aux input with time-limit}
FUNCTION AuxTC(Time :  Word) :  Char;       {As above for character data}


IMPLEMENTATION

{ --------------------------------------------------- }
{ This is the the new asynchronous interrupt routine. }
{ --------------------------------------------------- }

PROCEDURE AsyncInt;  INTERRUPT;

BEGIN
    Inline( $FA );                          { CLI - Disable interrupts }
    IF ((Port[PortBase + IIR] and RX_MASK) = RX_ID) AND
       ((Port[PortBase + LSR] and $10) = 0)
      THEN BEGIN
        PortBuf[EndBuf] := Port[PortBase + RX];
        Inc(EndBuf);
        EndBuf := EndBuf MOD BufSize;
      END;
    Port[ICR] := EOI;
    Inline( $FB );                          { STI - restart interrupts }
END;


{ --------------------------------------------- }
{ Enable the new asynchronous interrupt driver. }
{ --------------------------------------------- }

PROCEDURE InterruptEnable(Pnum :  Integer);

VAR       c,
          IntNo :  Integer;

BEGIN
    Inline( $FA );                          { CLI - Disable interrupts }

    CASE Pnum OF
      COM1,COM3 :  IntNo := $0C;
      COM2,COM4 :  IntNo := $0B;
    END;

    GetIntVec(IntNo, OldVect);            { save the old interrupt contents }
    SetIntVec(IntNo, @AsyncInt);          { now point to our routine }

    c := Port[PortBase + MCR] or MC_INT;
    Port[PortBase + MCR] := c;
    Port[PortBase + IER] := RX_INT;

    CASE Pnum OF
      COM1,COM3 :  c := Port[IMR] and IRQ4;
      COM2,COM4 :  c := Port[IMR] and IRQ3;
    END;

    Port[IMR] := c;
    Inline( $FB );                          { STI - restart interrupts }
END;


{ ------------------------------------------------------------- }
{ Return control to the original asynchronous interrupt driver. }
{ ------------------------------------------------------------- }

PROCEDURE InterruptDisable(Pnum :  Integer);

VAR       c,
          IntNo :  Integer;

BEGIN
    CASE Pnum OF
      COM1,COM3 :  BEGIN
                     c := Port[IMR] or (NOT IRQ4);
                     IntNo := $0C;
                   END;
      COM2,COM4 :  BEGIN
                     c := Port[IMR] or (NOT IRQ3);
                     IntNo := $0B;
                   END;
    END;

    Inline( $FA );                          { CLI - Disable interrupts }
    Port[IMR] := c;
    Port[PortBase + IER] := 0;
    c := Port[PortBase + MCR] and (NOT MC_INT);
    Port[PortBase + MCR] := c;

    SetIntVec(IntNo, OldVect);         { restore the old interrupt contents }
    Inline( $FB );                     { STI - restart interrupts }
END;


{ --------------------------- }
{ Set up the port parameters. }
{ --------------------------- }

PROCEDURE SetPort( PortNum : Byte;
                   Baudrate: Longint;
                   Parity,
                   Length,
                   StopBits: Integer);

VAR       c,
          Temp,
          Divisor :  Integer;

BEGIN
    CASE PortNum OF
      COM1 :  PortBase := COM1BASE;
      COM2 :  PortBase := COM2BASE;
      COM3 :  PortBase := COM3BASE;
      COM4 :  PortBase := COM4BASE;
    END;

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

    Inline( $FA );                          { CLI - Disable interrupts }
    c := Port[PortBase + LCR];
    Port[PortBase + LCR] := (c or $80);     {Access BRDL and BRDH regs}
    Port[PortBase + DLL] := lo(Divisor);
    Port[PortBase + DLH] := lo(Divisor SHR 8);
    Port[PortBase + LCR] := c;              {Back to THR / RDR regs}

    Temp := Length - 5;
    IF StopBits = 2 THEN
      Temp := Temp or 4;
    CASE Parity OF
      NO_PAR :  Temp := Temp or $00;
      OD_PAR :  Temp := Temp or $08;
      EV_PAR :  Temp := Temp or $18;
      MA_PAR :  Temp := Temp or $28;
      SP_PAR :  Temp := Temp or $38;
    END;
    Port[PortBase + LCR] := Temp;
    Running := TRUE;
    Inline( $FB );                          { STI - restart interrupts }
END;


{ -------------------------------- }
{ Open the port for communicatons. }
{ -------------------------------- }

PROCEDURE OpenComms;

VAR       c,
          Pnum :  Integer;

BEGIN
    StartBuf := 0;
    EndBuf := 0;

    Inline( $FA );                          { CLI - Disable interrupts }
    CASE PortBase OF
      COM1BASE :  Pnum := COM1;
      COM2BASE :  Pnum := COM2;
      COM3BASE :  Pnum := COM3;
      COM4BASE :  Pnum := COM4;
    END;
    InterruptEnable(Pnum);
    c := Port[PortBase + MCR] or DTR or RTS;
    Port[PortBase + MCR] := c;
    Inline( $FB );                          { STI - restart interrupts }
END;


{ --------------------------------------- }
{ Shut down the comms port when finished. }
{ --------------------------------------- }

PROCEDURE CloseComms;

VAR       Pnum :  Integer;

BEGIN
    Inline( $FA );                          { CLI - Disable interrupts }
    CASE PortBase OF
      COM1BASE :  Pnum := COM1;
      COM2BASE :  Pnum := COM2;
      COM3BASE :  Pnum := COM3;
      COM4BASE :  Pnum := COM4;
    END;
    Port[PortBase + MCR] := 0;
    InterruptDisable(Pnum);
    Inline( $FB );                          { STI - restart interrupts }
END;


{ -------------------------------- }
{ Set 'Data Terminal Ready' to on. }
{ -------------------------------- }

PROCEDURE RaiseDTR;

VAR       c :  Integer;

BEGIN
    c := Port[PortBase + MCR] or DTR;
    Inline( $FA );                          { CLI - Disable interrupts }
    Port[PortBase + MCR] := c;
    Inline( $FB );                          { STI - restart interrupts }
END;


{ --------------------------------- }
{ Set 'Data Terminal Ready' to off. }
{ --------------------------------- }

PROCEDURE LowerDTR;

VAR       c :  Integer;

BEGIN
    c := Port[PortBase + MCR];
    IF (c and DTR) = DTR THEN
      BEGIN
        Dec(c);                             { DTR = 1, thus dec = no DTR}
        Inline( $FA );                      { CLI - Disable interrupts }
        Port[PortBase + MCR] := c;
        Inline( $FB );                      { STI - restart interrupts }
      END
END;


{ ------------------------------------------------------------- }
{ Returns true if character(s) are waiting in the input buffer. }
{ ------------------------------------------------------------- }

FUNCTION CharWaiting :  Boolean;

BEGIN
    CharWaiting := (EndBuf <> StartBuf);
END;


{ ------------------------------------------------------- }
{ Returns the next character waiting in the input buffer. }
{ ------------------------------------------------------- }

FUNCTION GetAux :  Byte;

BEGIN
    GetAux := PortBuf[StartBuf];
    StartBuf := succ(StartBuf) MOD BufSize;    { wrap-around buffer if full }
END;


{ ------------------------------------------------------------------- }
{ This procedure is called by AuxWrite and actually does the sending. }
{ ------------------------------------------------------------------- }

PROCEDURE SendAux(b :  Byte);

VAR       timeout :  Word;

BEGIN
    Inline( $FA );                          { CLI - Disable interrupts }
    timeout := $FFFF;
    Port[PortBase + MCR] := OUT2 or DTR or RTS;
    WHILE ((Port[PortBase + MSR] and CTS) = 0) and (timeout > 0) DO
      Dec(timeout);
    timeout := $FFFF;
    WHILE ((Port[PortBase + LSR] and DSR) = 0) and (timeout > 0) DO
      Dec(timeout);
    Port[PortBase + TX] := b;
    Inline( $FB );                          { STI - restart interrupts }
END;


{ ---------------------------------------- }
{ Send the given string to the RS232 port. }
{ ---------------------------------------- }

PROCEDURE AuxWrite(StrToSend :  String);

VAR       Count,
          Psn,
          OldPsn:  Byte;

BEGIN
    OldPsn := 0;
    Psn := POS('^',StrToSend);
    WHILE Psn > OldPsn DO BEGIN    { Control character }
      Psn := POS('^',StrToSend);
      IF Length(StrToSend) > Psn then BEGIN
        StrToSend[Succ(Psn)] := Chr(Ord(UPCASE(StrToSend[Succ(Psn)]))-64);
        DELETE(StrToSend,Psn,1);
      END;
      OldPsn := Psn;
      Psn := POS('^',StrToSend);
    END;
    FOR Count := 1 to Length(StrToSend) DO
      CASE StrToSend[ Count ] OF
        '|' :  SendAux(13);                 { Carriage Return }
        '~' :  Delay(500);                  { 1/2 second pause }
      ELSE
        SendAux(Ord(StrToSend[Count]));
      END
END;


{ ---------------------------------------- }
{ Sends the given string to the modem raw. }
{ ---------------------------------------- }

PROCEDURE RawSend(StrToSend :  String);

VAR       Count:Byte;

BEGIN
    FOR Count := 1 to Length(StrToSend) DO SendAux(Ord(StrToSend[Count]));
END;


{ --------------------------------------------------- }
{ Returns true if a Carrier Detect signal is present. }
{ --------------------------------------------------- }

FUNCTION CarrierDetect :  Boolean;

BEGIN
    CarrierDetect := Running and ((Port[PortBase + MSR] and CD = CD) or Direct);
END;


{ ----------------------------------------- }
{ Allows user to escape during timed inputs }
{ ----------------------------------------- }

PROCEDURE TestAbort;

BEGIN
    Abort:=(KeyPressed and (ReadKey=#27)) or (not carrierdetect);
END;


{ ------------------------------------------ }
{ Reads byte from the com port with timeout. }
{ ------------------------------------------ }

FUNCTION AuxTB(Time: Word): Byte;

BEGIN
    Time:=Round(Time/10);
    Abort:=False;
    TimedOut:=False;
    If CharWaiting then AuxTB:=GetAux else begin
     Repeat
      Delay(10);
      TestAbort;
      Dec(Time);
     Until Abort or (Time=0) or CharWaiting;
     If CharWaiting then AuxTB:=GetAux else begin
      AuxTB:=255;
      TimedOut:=True;
     End;
    End;
END;


{ ------------------------------------------ }
{ Reads char from the com port with timeout. }
{ ------------------------------------------ }

FUNCTION AuxTC(Time: Word): Char;

BEGIN
    AuxTC:=Chr(AuxTB(Time));
END;

END.  { of Comms unit }
