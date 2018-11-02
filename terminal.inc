{ APNS Terminal Mode, simple keyboard access to the modem }

procedure terminal;

var
 c,t:char;

begin
 window(1,1,80,24);
 clrscr;
 currwindow:=$FF;
 if init(setup.cmdinit) then;
 cursoron;
 c:=#0;
 repeat
  job:='Terminal    ';
  if keypressed then begin
   sending:=true;
   status;
   c:=readkey;
   sendaux(ord(c));
   sending:=false;
  end;
  while charwaiting do begin
   t:=chr(getaux);
   write(t);
  end;
  if not charwaiting then status;
 until c=#27;
 cursoroff;
end;
