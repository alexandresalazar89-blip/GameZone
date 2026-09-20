#!/usr/bin/env python3
import argparse, json, math
from pathlib import Path
from PIL import Image, ImageDraw


TARGETS = {
    "Ghost1_red": ((221,0,0),(130,120,230,175)),
    "Ghost2_pink": ((255,153,153),(150,170,210,220)),
    "Ghost3_cyan": ((102,255,255),(125,170,180,220)),
    "Ghost4_orange": ((255,153,0),(180,170,235,220)),
    "Pacman": ((255,255,51),(145,255,225,325)),
}


def near(pixel,target,tol):
    return all(abs(int(pixel[i])-target[i])<=tol for i in range(3))


def centroid(im,target,bounds,tol=24):
    pix=im.load(); x0,y0,x1,y1=bounds
    sx=sy=n=0
    for y in range(y0,y1):
        for x in range(x0,x1):
            if near(pix[x,y],target,tol):
                sx+=x; sy+=y; n+=1
    return None if n<8 else {"x":sx/n,"y":sy/n,"pixels":n}


def maze_mask(im):
    pix=im.load(); pts=set()
    target=(0,51,255)
    for y in range(15,380):
        for x in range(8,352):
            # Ignore dynamic-character box while comparing maze geometry.
            if 130<=x<=230 and 125<=y<=225:
                continue
            if near(pix[x,y],target,36):
                pts.add((x,y))
    return pts


def f1(a,b):
    if not a or not b: return 0.0
    inter=len(a&b)
    precision=inter/len(a)
    recall=inter/len(b)
    return 0.0 if precision+recall==0 else 2*precision*recall/(precision+recall)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--imported",required=True)
    ap.add_argument("--oracle",required=True)
    ap.add_argument("--out-dir",required=True)
    args=ap.parse_args()
    out=Path(args.out_dir); out.mkdir(parents=True,exist_ok=True)
    imp=Image.open(args.imported).convert("RGB")
    ref=Image.open(args.oracle).convert("RGB")
    if imp.size!=(360,420) or ref.size!=(360,420):
        raise SystemExit(f"unexpected dimensions imported={imp.size} oracle={ref.size}")

    maze=f1(maze_mask(imp),maze_mask(ref))
    chars={}
    max_dist=0.0
    for name,(target,bounds) in TARGETS.items():
        a=centroid(imp,target,bounds)
        b=centroid(ref,target,bounds)
        if a is None or b is None:
            raise SystemExit(f"missing color centroid {name}: imported={a} oracle={b}")
        dist=math.hypot(a["x"]-b["x"],a["y"]-b["y"])
        max_dist=max(max_dist,dist)
        chars[name]={"imported":a,"oracle":b,"distance_px":round(dist,3)}

    passed=maze>=0.90 and max_dist<=4.0
    metrics={
        "schema":1,
        "comparison_scope":"B4 visual only; pellets intentionally excluded because logical Maze population is B5",
        "maze_blue_mask_f1":round(maze,6),
        "max_character_centroid_distance_px":round(max_dist,3),
        "characters":chars,
        "thresholds":{"maze_blue_mask_f1_min":0.90,"character_centroid_distance_px_max":4.0},
        "pass":passed,
    }
    (out/"comparison_metrics.json").write_text(json.dumps(metrics,indent=2)+"\n","utf-8")

    canvas=Image.new("RGB",(720,452),"white")
    canvas.paste(imp,(0,32)); canvas.paste(ref,(360,32))
    draw=ImageDraw.Draw(canvas)
    draw.text((8,8),"Godot B4 imported visual",(0,0,0))
    draw.text((368,8),"Ruffle B2 oracle f00106",(0,0,0))
    draw.text((8,436),f"maze F1={maze:.4f}  max character centroid delta={max_dist:.2f}px  PASS={passed}",(0,0,0))
    canvas.save(out/"imported_vs_oracle.png")
    print("[B4_COMPARE] "+json.dumps(metrics,sort_keys=True))
    if not passed:
        raise SystemExit("B4 visual comparison failed")


if __name__=="__main__":
    main()
