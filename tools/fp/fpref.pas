{ fpref.pas - reference results for kernel/fp.s, computed by Free Pascal on x86-64 exactly as the
  oracle build computes them (SSE for double expressions, x87 for extended ones and sin/cos/arctan).
  Reads records from paramstr(1), writes results to paramstr(2). Record (little-endian, 32 bytes):
  op: word; w: word; d: word; pad: word; a: 10 bytes extended (or double in the first 8); pad 2;
  b: 10 bytes; pad 2. Result: 16 bytes (extended in 10 / double in 8 / longint in 4 / string). }
{$mode tp}
program fpref;
type rec = packed record op, w, d, pad: word; a: array[0..11] of byte; b: array[0..11] of byte; end;
var f, g: file; r: rec; o: array[0..15] of byte;
    da, db, dc: double; ea, eb, ec: extended; l: longint; s: string; i: integer;
begin
 assign(f, paramstr(1)); reset(f, 1);
 assign(g, paramstr(2)); rewrite(g, 1);
 while not eof(f) do
  begin
   blockread(f, r, sizeof(r));
   fillchar(o, sizeof(o), 0);
   move(r.a, da, 8); move(r.b, db, 8);
   move(r.a, ea, 10); move(r.b, eb, 10);
   case r.op of
    0: begin dc := da + db; move(dc, o, 8); end;
    1: begin dc := da - db; move(dc, o, 8); end;
    2: begin dc := da * db; move(dc, o, 8); end;
    3: begin dc := da / db; move(dc, o, 8); end;
    4: begin dc := sqrt(da); move(dc, o, 8); end;
    5: begin ec := ea + eb; move(ec, o, 10); end;
    6: begin ec := ea - eb; move(ec, o, 10); end;
    7: begin ec := ea * eb; move(ec, o, 10); end;
    8: begin ec := ea / eb; move(ec, o, 10); end;
    9: begin ec := sqrt(ea); move(ec, o, 10); end;
    10: begin dc := ea; move(dc, o, 8); end;
    11: begin l := round(da); move(l, o, 4); end;
    12: begin l := trunc(da); move(l, o, 4); end;
    13: begin l := round(ea); move(l, o, 4); end;
    14: begin dc := sin(da); move(dc, o, 8); end;
    15: begin dc := cos(da); move(dc, o, 8); end;
    16: begin dc := arctan(da); move(dc, o, 8); end;
    17: begin str(da:r.w:r.d, s); move(s, o, 16); end;
    18: begin move(r.a, l, 4); dc := l; move(dc, o, 8); end;
    19: begin if da < db then o[0] := $ff else if da > db then o[0] := 1; end;
    20: begin ec := sin(ea); move(ec, o, 10); end;
    21: begin ec := cos(ea); move(ec, o, 10); end;
    22: begin ec := arctan(ea); move(ec, o, 10); end;
   end;
   blockwrite(g, o, 16);
  end;
 close(f); close(g);
end.
