from pypdf import PdfReader
from pypdf.generic import ContentStream, TextStringObject, ByteStringObject, ArrayObject
from pathlib import Path
import re

PDF = Path('samples/pdf/hardwrap_en.pdf')
reader = PdfReader(str(PDF))
page = reader.pages[0]

fonts = page['/Resources']['/Font']
font_keys = [k[1:] if k.startswith('/') else k for k in fonts.keys()]
print('A.font_keys=', font_keys)
print('A.has_C1=', 'C1' in font_keys)

# parse ToUnicode map for C1
c1 = fonts['/C1'].get_object()
cmap_stream = c1['/ToUnicode'].get_object().get_data().decode('utf-8', 'strict')

# emulate project parse_tounicode_cmap

def parse_hex_int(s: str) -> int:
    v = 0
    for c in s:
        if '0' <= c <= '9':
            d = ord(c)-48
        elif 'A' <= c <= 'F':
            d = 10 + ord(c)-65
        elif 'a' <= c <= 'f':
            d = 10 + ord(c)-97
        else:
            return v
        v = v*16 + d
    return v

def all_hex_between_angles(line: str):
    return re.findall(r'<([^>]*)>', line)

def decode_utf16be_hex(h: str) -> str:
    if len(h)%4 != 0:
        return ''
    out=[]
    for i in range(0,len(h),4):
        cp = int(h[i:i+4],16)
        if 0xD800 <= cp <= 0xDFFF:
            return ''
        if 0 <= cp <= 0x10FFFF:
            out.append(chr(cp))
    return ''.join(out)

cmap={}
widths=set()
for raw in cmap_stream.splitlines():
    line=raw.strip()
    hs=all_hex_between_angles(line)
    if hs:
        src=hs[0]
        if len(src)%2==0 and 1 <= len(src)//2 <= 4:
            widths.add(len(src)//2)
    if 'beginbfchar' in line or 'beginbfrange' in line:
        continue
    if len(hs)==2:
        src=parse_hex_int(hs[0])
        dst=decode_utf16be_hex(hs[1])
        if dst:
            cmap[src]=dst
    elif len(hs)==3:
        start=parse_hex_int(hs[0]); end=parse_hex_int(hs[1]); dst_start=parse_hex_int(hs[2])
        if end>=start:
            for i in range(end-start+1):
                cp=dst_start+i
                if 0 <= cp <= 0x10FFFF:
                    cmap[start+i]=chr(cp)

code_widths=sorted(widths, reverse=True) or [1]
print('D.code_widths=', code_widths)
print('D.cmap_size=', len(cmap))

cs = ContentStream(page.get_contents(), reader)
current_font=None
print('B.events:')
for idx,(operands,opb) in enumerate(cs.operations):
    op=opb.decode('latin1')
    if op=='Tf' and len(operands)>=2:
        name=str(operands[0])
        current_font = name[1:] if name.startswith('/') else name
        print(f'  Tf#{idx}: current_font={current_font}')
    if op=='Tj' and operands:
        operand=operands[-1]
        hit=current_font in font_keys if current_font else False
        if isinstance(operand, TextStringObject):
            kind='String'
            raw = getattr(operand, "original_bytes", None)
            if raw is None:
                bs = str(operand).encode("utf-16-be", "ignore")
            else:
                bs = raw
        elif isinstance(operand, ByteStringObject):
            kind='HexString'; bs=bytes(operand)
        else:
            kind=type(operand).__name__; bs=b''
        # emulate decode_text_operand_with_font for hex bytes with cmap + widths
        out=[]; i=0; n=len(bs)
        while i<n:
            matched=False
            for w in code_widths:
                if w<=0 or i+w>n:
                    continue
                code=0
                for j in range(w):
                    code=code*256 + bs[i+j]
                if code in cmap:
                    out.append(cmap[code]); i+=w; matched=True; break
            if not matched:
                # Type0 Identity-H fallback (2-byte)
                if i+1<n:
                    cp = bs[i]*256 + bs[i+1]
                    out.append(chr(cp) if cp<=0x10FFFF else '')
                    i+=2
                else:
                    out.append(chr(bs[i])); i+=1
        decoded=''.join(out)
        print(f'  Tj#{idx}: font={current_font} hit={hit} operand={kind} bytes_len={len(bs)} decode_len={len(decoded)} sample={decoded[:20]!r}')

full = page.extract_text() or ''
print('F.text_non_empty=', bool(full.strip()), 'len=', len(full))
