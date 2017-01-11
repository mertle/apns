{*************************************************************************}

function dos2unix(dt:datetime):longint;

var
 day,month,year:integer;

begin
 day:=dt.day;
 month:=dt.month;
 year:=dt.year;
 dec(year,1900);
 dec(month,3);
 if month<0 then begin
  inc(month,12);
  dec(year);
 end;
 dos2unix:=((trunc(year*365.25)+round(month*30.6)+day-25509)*86400)+
           (longint(dt.hour)*3600)+(dt.min*60)+dt.sec;
end;

{*************************************************************************}

procedure unix2dos(unix:longint;var dt:datetime);

var
 day,month,year:integer;
 time:longint;

begin
 time:=unix mod 86400;
 with dt do begin
  hour:=time div 3600;
  min:=(time-longint(hour)*3600) div 60;
  sec:=(time mod 60);
 end;
 unix:=unix div 86400;
 inc(unix,25509);
 year:=trunc(unix/365.25);
 day:=unix-trunc(year*365.25);
 month:=trunc(day/30.6);
 day:=round(day-month*30.6);
 if day=0 then begin
  day:=31;
  dec(month);
 end;
 inc(month,3);
 if month>12 then begin
  dec(month,12);
  inc(year);
 end;
 if (month=2) and (day=31) then day:=29;
 inc(year,1900);
 dt.day:=day;
 dt.month:=month;
 dt.year:=year;
end;

{*************************************************************************}