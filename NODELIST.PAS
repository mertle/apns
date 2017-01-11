{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S+,V-,X-}
{$M 16384,0,655360}

program nodelist_utility;

{Nodelist.Dat is sorted alphabetically by name,
 Nodelist.Idx is an index sorted by node-id}

uses dos,crt;

{$I apdefs.inc}

type
 nodeid=string[4];
 node=record
       sitename:string[40];
       sitenumber:string[40];
       sitecode:nodeid;
       days:byte;
       status:byte;
       attempts:word;
      end;
 index=record
        sitecode:nodeid;
        point:longint;
       end;

const
 base36:array [0..35] of char='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

var
 nfile:file of node;
 ifile:file of index;
 tfile:text;
 currnode,tempnode:node;
 currindex,tempindex:index;
 indexsize,target,loop,half:longint;
 s:string;
 iter:byte;
 total:longint;
 scode:nodeid;
 site,region,country:longint;
 bigarray:array [0..7000] of index;

procedure sort(l,r: integer);

var
 i,j: integer;
 x,y:index;

begin
 i:=l; j:=r; x:=bigarray[(l+r) DIV 2];
 repeat
  while bigarray[i].sitecode<x.sitecode do inc(i);
  while x.sitecode<bigarray[j].sitecode do dec(j);
  if i<=j then begin
   y:=bigarray[i]; bigarray[i]:=bigarray[j]; bigarray[j]:=y;
   inc(i); dec(j);
  end;
 until i>j;
 if l<j then sort(l,j);
 if i<r then sort(i,r);
end;

procedure encode(var id:nodeid;site,region,country:longint);

var
 temp,halfway:longint;

begin
 halfway:=site+(region*256)+(country*32768);
 temp:=halfway div 46656;
 dec(halfway,temp * 46656);
 id[1]:=base36[temp];
 temp:=halfway div 1296;
 dec(halfway,temp * 1296);
 id[2]:=base36[temp];
 temp:=halfway div 36;
 dec(halfway,temp * 36);
 id[3]:=base36[temp];
 id[4]:=base36[halfway];
 id[0]:=#4;
end;

procedure decode(id:nodeid;var site,region,country:longint);

var
 temp:longint;

begin
 temp:=pred(pos(id[4],base36));
 inc(temp,(pred(pos(id[3],base36))*36));
 inc(temp,(pred(pos(id[2],base36))*1296));
 inc(temp,(pred(pos(id[1],base36))*46656));
 country:=temp div 32768;
 dec(temp,country*32768);
 region:=temp div 256;
 dec(temp,region*256);
 site:=temp;
end;

begin
 checksnow:=false;
 clrscr;
 writeln;
 writeln('APNS NodeList Maintenance Utility v',version,', Copyright (c) 1991 M. E. Ralphson');
 writeln;
 country:=1; {France}
 assign(nfile,'NODELIST.DAT');
 assign(tfile,'405.TXT');
 reset(tfile);
 reset(nfile);
 if ioresult<>0 then begin
  writeln('Building new NodeList.Dat file...');
  writeln;
  rewrite(nfile);
  country:=1;
  for region:=1 to 9 do
  for site:=1 to 45 do begin
   fillchar(currnode,sizeof(currnode),#0);
   total:=succ(random(9));
   half:=succ(random(45));
   encode(currnode.sitecode,{site}half,{region}total,country);
   readln(tfile,s);
   write(#13,s);
   clreol;
   currnode.sitename:=s;
   write(nfile,currnode);
  end;
  close(nfile);
  close(tfile);
  writeln(#10);
 end;
 writeln('Rebuilding index...');
 reset(nfile);
 indexsize:=pred(filesize(nfile));
 for loop:=0 to indexsize do begin
  read(nfile,currnode);
  bigarray[loop].sitecode:=currnode.sitecode;
  bigarray[loop].point:=loop;
 end;
 sort(0,indexsize);
 assign(ifile,'NODELIST.IDX');
 rewrite(ifile);
 for loop:=0 to indexsize do write(ifile,bigarray[loop]);
 close(ifile);
 writeln;
 reset(nfile);
 for loop:=0 to indexsize do begin
  write(#13,'Checking for structure errors... ',round((loop/indexsize)*100):3,'%');
  seek(nfile,bigarray[loop].point);
  read(nfile,currnode);
  if bigarray[loop].sitecode<>currnode.sitecode then
   writeln(#10#13,currnode.sitename,' Mismatch! #',loop,#7);
 end;
 close(nfile);
 writeln(#10#13);
 writeln(succ(indexsize),' nodes processed.');

{

 write('Region (1-9): ');
 readln(region);
 write('Site (1-45): ');
 readln(site);
 encode(scode,site,region,country);
 writeln('Looking for site code: ',scode);
 iter:=0;
 loop:=filesize(nfile) div 2;
 half:=loop div 2;
 repeat
  seek(nfile,loop);
  read(nfile,current);
  inc(iter);
  if scode=current.sitecode then else
  if scode>current.sitecode then inc(loop,half)
   else dec(loop,half);
  half:=round(half/2);
 until current.sitecode=scode;
 writeln('Found in ',iter,' seeks to the nodelist file');
 close(nfile);}
end.
