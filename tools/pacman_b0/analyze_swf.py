#!/usr/bin/env python3
import argparse, collections, hashlib, json, re, struct, zlib
from pathlib import Path
import xml.etree.ElementTree as ET


def bits(data, pos, n):
    v = 0
    for _ in range(n):
        v = (v << 1) | ((data[pos // 8] >> (7 - pos % 8)) & 1)
        pos += 1
    return v, pos


def sint(v, n):
    return v - (1 << n) if v & (1 << (n - 1)) else v


def swf_header(path):
    raw = Path(path).read_bytes()
    sig = raw[:3].decode('ascii')
    ver = raw[3]
    declared = struct.unpack_from('<I', raw, 4)[0]
    if sig == 'FWS': body, compression = raw[8:], 'none'
    elif sig == 'CWS': body, compression = zlib.decompress(raw[8:]), 'zlib'
    elif sig == 'ZWS': raise RuntimeError('ZWS/LZMA header parsing intentionally stops B0 rather than guessing')
    else: raise RuntimeError(f'Unexpected SWF signature {sig!r}')
    pos = 0
    nbits, pos = bits(body, pos, 5)
    vals = []
    for _ in range(4):
        v, pos = bits(body, pos, nbits); vals.append(sint(v, nbits))
    rb = (pos + 7) // 8
    fps = struct.unpack_from('<H', body, rb)[0] / 256.0
    frames = struct.unpack_from('<H', body, rb + 2)[0]
    xmin, xmax, ymin, ymax = vals
    return {
        'signature': sig, 'compression': compression, 'swf_version': ver,
        'declared_file_length': declared, 'actual_file_length': len(raw),
        'frame_rate': fps, 'frame_count': frames,
        'stage_twips': {'xmin': xmin, 'xmax': xmax, 'ymin': ymin, 'ymax': ymax},
        'stage_px': {'x': xmin/20, 'y': ymin/20, 'width': (xmax-xmin)/20, 'height': (ymax-ymin)/20},
        'sha256': hashlib.sha256(raw).hexdigest(),
    }


def tag_counts(xml_path):
    out = collections.Counter()
    for _, el in ET.iterparse(xml_path, events=('start',)):
        out[el.tag.rsplit('}',1)[-1]] += 1
    return out


def scripts(root):
    out=[]; root=Path(root)
    for p in sorted(root.rglob('*.as')):
        out.append((str(p.relative_to(root)), p.read_text('utf-8', errors='replace')))
    return out


def as_kind(tags, src):
    text='\n'.join(t for _,t in src)
    avm2=any(k.startswith('DoABC') for k in tags)
    avm1=tags.get('DoAction',0)>0 or tags.get('DoInitAction',0)>0
    if avm2 and avm1: return 'mixed AVM1 + AVM2','mixed'
    if avm2: return 'AVM2','ActionScript 3'
    if avm1:
        if re.search(r'\bclass\s+[A-Za-z_$]', text) or re.search(r'\bextends\s+[A-Za-z_$]', text):
            return 'AVM1','ActionScript 2 style'
        if '_root' in text or 'Key.isDown' in text or 'MovieClip.prototype' in text:
            return 'AVM1','ActionScript 1/2 timeline style'
        return 'AVM1','ActionScript 1/2 (exact dialect is not encoded as a SWF flag)'
    return 'none','none'


def counts(tags):
    prefixes=('DefineShape','DefineSprite','DefineBits','DefineButton','DefineFont','DefineText','DefineEditText','DefineMorphShape','DefineVideoStream','DefineSound')
    return {
      'defined_character_tags': sum(v for k,v in tags.items() if k.startswith(prefixes)),
      'sprites': sum(v for k,v in tags.items() if k.startswith('DefineSprite')),
      'shapes': sum(v for k,v in tags.items() if k.startswith('DefineShape')),
      'images': sum(v for k,v in tags.items() if k.startswith('DefineBits')),
      'sounds': sum(v for k,v in tags.items() if k.startswith('DefineSound')),
      'fonts': sum(v for k,v in tags.items() if k.startswith('DefineFont')),
      'texts': sum(v for k,v in tags.items() if k.startswith('DefineText') or k=='DefineEditText'),
      'buttons': sum(v for k,v in tags.items() if k.startswith('DefineButton')),
    }


def excerpt(src):
    if not src: return {'path':None,'line_start':None,'excerpt':'','reason':'No scripts exported'}
    def score(item):
        p,t=item; s=(p+'\n'+t).lower(); total=min(len(t)//500,10)
        for term,pts in [('pacman',20),('pac_man',16),('ghost',12),('key.isdown',8),('onenterframe',7),('_x',6),('_y',6),('direction',5),('speed',4),('hittest',4)]:
            if term in s: total += pts
        return total
    p,t=max(src,key=score); ls=t.splitlines(); anchor=0
    for term in ['pacman','key.isdown','onenterframe','_x','_y','ghost','direction','speed']:
        hit=next((i for i,l in enumerate(ls) if term in l.lower()),None)
        if hit is not None: anchor=hit; break
    start=max(0,anchor-1); picked=[]; chars=0
    for line in ls[start:start+8]:
        line=line.rstrip()
        if not line: continue
        if chars+len(line)>360: break
        picked.append(line); chars+=len(line)
        if len(picked)>=4: break
    return {'path':p,'line_start':start+1,'excerpt':'\n'.join(picked),'reason':'Highest B0 movement/character-logic score'}


def obfuscation(src):
    if not src: return {'status':'ambiguous','evidence':['No ActionScript source exported']}
    lines=readable=repl=longids=huge=0
    for _,t in src:
        repl += t.count('\ufffd'); longids += len(re.findall(r'\b[A-Za-z_$][A-Za-z0-9_$]{48,}\b',t))
        for l in t.splitlines():
            s=l.strip()
            if not s: continue
            lines+=1; huge += int(len(s)>500)
            readable += int(bool(re.search(r'\b(?:if|for|while|function|switch|gotoAndStop|Key\.isDown)\b',s)))
    ratio=huge/max(lines,1)
    status='possible_obfuscation_or_decompiler_damage' if repl or longids>5 or ratio>0.10 or readable==0 else 'no_obvious_obfuscation_in_b0'
    return {'status':status,'evidence':[f'decompiled scripts: {len(src)}',f'non-empty source lines: {lines}',f'readable control-flow/Flash API lines: {readable}',f'replacement characters: {repl}',f'very-long identifier hits: {longids}',f'>500-char line ratio: {ratio:.4f}']}


def main():
    a=argparse.ArgumentParser()
    for n in ['swf','xml','scripts','ffdec_tag','ffdec_asset','ruffle_tag','ruffle_asset','java_version','ruffle_version_output','ffdec_help_head','out_json','out_plan']:
        a.add_argument('--'+n.replace('_','-'),required=n not in ('ruffle_version_output','ffdec_help_head'),default='')
    x=a.parse_args(); h=swf_header(x.swf); tc=tag_counts(x.xml); src=scripts(x.scripts); vm,style=as_kind(tc,src); cc=counts(tc); ex=excerpt(src); ob=obfuscation(src)
    result={'b0_gate':'triage_only','source_url':'https://raw.githubusercontent.com/AmmarSAA/flash-games-directory/main/pacman.swf','swf':h,'actionscript':{'vm':vm,'source_style':style,'script_files_exported_for_triage':len(src),'obfuscation':ob,'central_excerpt':ex},'counts':cc,'tag_counts':dict(sorted(tc.items())),'toolchain':{'java':x.java_version,'ffdec_release':x.ffdec_tag,'ffdec_asset':x.ffdec_asset,'ruffle_release':x.ruffle_tag,'ruffle_asset':x.ruffle_asset,'ruffle_version_output':x.ruffle_version_output,'ffdec_help_head':x.ffdec_help_head}}
    Path(x.out_json).parent.mkdir(parents=True,exist_ok=True); Path(x.out_json).write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n','utf-8')
    st=h['stage_px']; tw=h['stage_twips']; ev='\n'.join('- '+e for e in ob['evidence']); code=ex['excerpt'] or '(no excerpt available)'
    plan=f'''# PACMAN_PORT_PLAN\n\nStatus: **B0 TRIAGE COMPLETE — STOP / WAIT FOR GO BEFORE B1.**\n\n## Source of truth\n\n- SWF: games/pacman/original/pacman.swf\n- Source URL: {result['source_url']}\n- SHA-256: {h['sha256']}\n- Port rule: decompiled ActionScript + extracted SWF assets are authoritative. No arcade-original substitutions, redesigns, or guessed behavior.\n\n## B0 toolchain — exact runner versions\n\n- Java: **{x.java_version}**\n- FFDec release: **{x.ffdec_tag}**\n- FFDec asset: {x.ffdec_asset}\n- Ruffle release: **{x.ruffle_tag}**\n- Ruffle asset: {x.ruffle_asset}\n- Ruffle version command: {x.ruffle_version_output or '(version command unavailable; release tag recorded)'}\n\nFFDec CLI flags were verified on the runner; the help header was:\n\n~~~text\n{x.ffdec_help_head}\n~~~\n\n## B0 SWF triage\n\n- SWF signature/compression: **{h['signature']} / {h['compression']}**\n- SWF version: **{h['swf_version']}**\n- ActionScript VM: **{vm}**\n- Decompiled source style: **{style}**\n- Frame rate: **{h['frame_rate']:.6g} fps**\n- Fixed-step target: **1 / {h['frame_rate']:.6g} s per SWF frame**\n- Main timeline frame count: **{h['frame_count']}**\n- Stage origin: **({st['x']:.6g}, {st['y']:.6g}) px**\n- Stage size: **{st['width']:.6g} × {st['height']:.6g} px**\n- Stage RECT twips: {tw}\n- SWF size: **{h['actual_file_length']} bytes**\n\n### Definitions visible at B0\n\n- Defined character tags: **{cc['defined_character_tags']}**\n- Sprites: **{cc['sprites']}**\n- Shapes: **{cc['shapes']}**\n- Images: **{cc['images']}**\n- Sounds: **{cc['sounds']}**\n- Fonts: **{cc['fonts']}**\n- Text definitions: **{cc['texts']}**\n- Buttons: **{cc['buttons']}**\n- ActionScript files exported only for B0 readability triage: **{len(src)}**\n\nThe full immutable FFDec export to games/pacman/decompiled is **not** performed until B1.\n\n## Obfuscation / readability gate\n\nAssessment: **{ob['status']}**\n\n{ev}\n\nIf B1 exposes damaged or ambiguous logic, the port stops there instead of guessing.\n\n## Real decompiled ActionScript excerpt\n\nSelected file: {ex['path'] or '(none)'}\nApprox. starting line: {ex['line_start'] or 'n/a'}\n\n~~~actionscript\n{code}\n~~~\n\nSelection note: {ex['reason']}. The complete raw scripts are deferred to B1.\n\n## Flash semantic contract\n\n- _x/_y are pixels; Y points down.\n- 20 twips = 1 px.\n- _xscale/_yscale are percent.\n- _rotation is degrees.\n- _alpha is 0–100.\n- Preserve Flash depth order and the SWF's actual hitTest usage.\n- Drive gameplay by SWF frames at **{h['frame_rate']:.6g} fps** unless source explicitly uses time.\n- Preserve symbol names, frame labels, variables and function names.\n\n## Phase gates\n\n- **B0 — COMPLETE:** triage only.\n- **B1 — PENDING GO:** total FFDec export + ASSET_MANIFEST + SYMBOL_MAP + TIMELINE_MAP.\n- **B2 — PENDING:** pinned Ruffle oracle and deterministic scenarios.\n- **B3 — PENDING:** minimal Flash runtime shim.\n- **B4 — PENDING:** SWF assets and timelines.\n- **B5 — PENDING:** 1:1 ActionScript port.\n- **B6 — PENDING:** A2 GameModule integration.\n- **B7 — PENDING:** oracle behavior/frame diff and VERIFICATION.md.\n- **B8 — PENDING:** Web packaging and Pages desktop/phone verification.\n\nSingle-threaded remains mandatory. Physical gamepad remains deferred under BL-001.\n\n## B0 gate\n\n**STOP HERE. Do not start B1 until explicit user GO.**\n'''
    Path(x.out_plan).write_text(plan,'utf-8')

if __name__=='__main__': main()
