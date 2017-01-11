{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-}
{$M 1024,0,655360}
unit sound;

interface

uses crt;

const
 hz:array [1..84] of word=(65,69,73,78,82,87,93,98,104,110,117,124,131,139,
     147,156,165,175,185,196,208,220,233,247,262,277,294,311,330,349,370,
     392,415,440,466,494,523,554,587,622,659,698,740,784,830,880,932,988,
     1046,1108,1174,1244,1318,1396,1480,1568,1660,1760,1864,1976,2092,2216,
     2348,2488,2636,2792,2960,3136,3320,3520,3728,3952,4184,4432,4696,4976,
     5272,5584,5920,6272,6640,7040,7456,7904);

function ucase(s:string):string;

procedure play(s:string);

implementation

function ucase(s:string):string;

var
 temp:string;
 loop:byte;

begin
 temp:='';
 for loop:=1 to length(s) do temp:=temp+upcase(s[loop]);
 ucase:=temp;
end;

function arg(s:string;var b:byte):byte;

var
 temp:string;
 code:integer;
 yat:byte;

begin
 inc(b);
 temp:='';
 while s[b] in ['0'..'9'] do begin
  temp:=temp+s[b];
  inc(b);
 end;
 val(temp,yat,code);
 arg:=yat;
end;

procedure play(s:string);

const
 octave:byte=4;
 duration:byte=4;
 tempo:word=2000;
 staccato:real=0.875;

var
 s2:string;
 dur:word;
 c:char;
 note,n2:word;
 b,b2:byte;

begin
 s:=ucase(s)+' ';
 b:=1;
 repeat
  c:=s[b];
  b2:=arg(s,b);
  note:=0;
  case c of
   'T':tempo:=round(240000/b2);
   'O':if b2 in [0..6] then octave:=b2;
   '>':if octave<6 then inc(octave);
   '<':if octave>0 then dec(octave);
   'L':if b2 in [1..64] then duration:=b2;
   'M':if s[succ(b)] in ['S','N','L'] then begin
        inc(b);
        case s[b] of
         'S':staccato:=0.75;
         'N':staccato:=0.875;
         'L':staccato:=1.0;
        end;
       end;
   'P':begin
        if b2=0 then b2:=duration;
        delay(tempo div b2);
        while s[succ(b)]='.' do begin
         inc(b);
         b2:=b2 shl 1;
         delay(tempo div b2);
        end;
       end;
   'C':note:=1;
   'D':note:=3;
   'E':note:=5;
   'F':note:=6;
   'G':note:=8;
   'A':note:=10;
   'B':note:=12;
   else;
  end;
  if note>0 then begin
   if s[b] in ['+','#'] then begin
    inc(b);
    inc(note);
   end else if s[b]='-' then begin
    inc(b);
    dec(note);
   end;
   n2:=note+(octave*12);
   if b2=0 then b2:=duration;
   dur:=tempo div b2;
   while s[b]='.' do begin
    inc(b);
    dur:=round(dur*1.5);
   end;
   crt.sound(hz[n2]);
   delay(round(staccato*dur));
   nosound;
   delay(round((1-staccato)*dur));
  end;
 until b>length(s);
end;

end.
