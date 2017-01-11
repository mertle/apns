{Communications Test Include file, IfDef Debug Only}

procedure commtest;

var
 c:char;
 i:byte;

begin
 clrscr;
 write('Receive Test or Send Test (R/S) ?');
 c:=upcase(readkey);
 case c of
  'R':begin
       writeln(#13#10'Press any key to finish the test...'#10);
       while not keypressed do begin
        if charwaiting then write(auxtb(1000):4);
       end;
       c:=readkey;
       writeln(#13#10'Finished');
      end;
  'S':begin
       for i:=0 to 255 do sendaux(i);
       writeln(#13#10'Finished');
      end;
  else;
 end;
end;
