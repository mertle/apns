{ APNS Terminal Mode, simple keyboard access to the modem }

procedure terminal;

var
 c:char;

begin
 if init(setup.cmdinit) then;
 win(3);
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
  if not charwaiting then status;
  while charwaiting do receive;
 until c=#27;
 cursoroff;
end;
