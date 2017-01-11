type
 lhaheader=record
  hcrc:word;
  ctype:array [1..5] of char;
  csize:longint;
  fsize:longint;
  ftime:longint;
  fattr:byte;
  level:byte;
  fname:string[12];
 end;

procedure chktransit(s:string);

var
 f:file;
 header:lhaheader;
 fsize,move:longint;
 ioerr:word;
 ok:boolean;

{--------------------------------------------------------------------------}

 procedure extract;

 var
  o:file;
  dir:dirstr;
  name:namestr;
  ext:extstr;
  oname,stem:string;
  loop,bread:word;
  move:longint;
  addlen:byte;

 begin
  move:=filepos(f)-12+length(header.fname);
  if header.level=0 then addlen:=2 else addlen:=5;
  inc(move,addlen);
  seek(f,move);

  fsplit(header.fname,dir,name,ext);
  loop:=0;
  stem:=setup.updir+'\'+name+'.';
  oname:=stem+'LZH';
  while (exist(oname)) and (loop<1000) do begin
   oname:=stem+itos(loop,3);
   inc(loop);
  end;
  if loop>999 then exit;
  writeln('Rerouting: ',oname);
  allocbuf;
  assign(o,oname);
  rewrite(o,1);
  repeat
   blockread(f,buf^,buflen,bread);
   blockwrite(o,buf^,bread);
  until bread<buflen;
  close(o);
  mem_free(bufseg);
 end;

{--------------------------------------------------------------------------}

begin
 assign(f,s);
 reset(f,1);
 fsize:=filesize(f);
 repeat
  blockread(f,header,sizeof(header));
  ioerr:=ioresult;
  ok:=(header.ctype[1]='-') and (header.ctype[5]='-');
  if ok then begin
   move:=filepos(f);
   inc(move,header.csize+length(header.fname)-7);
   if pos('.TRN',header.fname)>0 then begin
    extract;
   end;
   seek(f,move);
  end;
 until (filesize(f)-filepos(f)<20) or (not ok);
 ioerr:=ioresult;
 close(f);
end;

{*************************************************************************}

procedure killtransit(s:string);

var
 f:file;
 header:lhaheader;
 ok,present:boolean;
 move,fsize:longint;
 ioerr:word;

begin
 present:=false;
 assign(f,s);
 reset(f,1);
 fsize:=filesize(f);
 repeat
  blockread(f,header,sizeof(header));
  move:=filepos(f);
  inc(move,header.csize+length(header.fname)-7);
  ok:=(header.ctype[1]='-') and (header.ctype[5]='-');
  if ok and (pos('.TRN',header.fname)>0) then present:=true;
  seek(f,move);
 until (fsize-filepos(f)<20) or (not ok);
 ioerr:=ioresult;
 close(f);
 if present then run('LHA D /CM '+s+' *.TRN');
end;

{*************************************************************************}

procedure route;

var
 sr:searchrec;

begin
 win(2);
 job:='Re-Routing  ';
 status;
 findfirst(setup.downdir+'\*.*',0,sr);
 while doserror=0 do begin
  chktransit(setup.downdir+'\'+sr.name);
  findnext(sr);
 end;

 findfirst(setup.downdir+'\*.*',0,sr);
 while doserror=0 do begin
  killtransit(setup.downdir+'\'+sr.name);
  findnext(sr);
 end;
end;

{**************************************************************************}

procedure onebyone(dir,original:string);

var
 sr:searchrec;
 oldest:longint;
 oldname,lastname,s:string;

begin
 oldname:='';
 repeat
  lastname:=oldname;
  oldest:=$7FFFFFFF; {Quite a big number}
  oldname:='';
  findfirst(dir+'\*.*',0,sr);
  while doserror=0 do begin
   if sr.time<oldest then begin
    oldest:=sr.time;
    oldname:=dir+'\'+sr.name;
   end;
   findnext(sr);
  end;
  if oldname<>'' then begin
   s:=original;
   replace(s,'%FILE',oldname,false);
   if s<>'' then run(s);
  end;
 until (oldname='') or (oldname=lastname); 
end;
