#!/usr/bin/env python3
import argparse, json, re
from collections import deque
from pathlib import Path

DIRS=[(0,-1,"Up"),(1,0,"Right"),(0,1,"Down"),(-1,0,"Left")]
POWER_SEQUENCE=[(26,23),(26,3),(1,3),(1,23)]
POWER_TARGET_INDICES=[20,85,160,245]

def parse_maze(path):
    text=Path(path).read_text("utf-8",errors="replace")
    m=re.search(r'\bm\s*=\s*"([^"]+)"\s*;',text)
    if not m: raise SystemExit("Maze literal not found")
    maze=m.group(1)
    if len(maze)!=28*31: raise SystemExit(f"Unexpected maze length {len(maze)}")
    return {(x,y):maze[y*28+x] for y in range(31) for x in range(28)}

def neighbors(grid,p,blocked=set()):
    x,y=p
    for dx,dy,name in DIRS:
        q=(x+dx,y+dy)
        if q in grid and grid[q]!="#" and q not in blocked:
            yield q,name

def shortest(grid,a,b,blocked=set()):
    q=deque([a]); prev={a:(None,None)}
    while q:
        p=q.popleft()
        if p==b: break
        for n,d in neighbors(grid,p,blocked-{b}):
            if n not in prev:
                prev[n]=(p,d); q.append(n)
    if b not in prev: return None
    out=[]; cur=b
    while cur!=a:
        parent,d=prev[cur]; out.append((cur,d)); cur=parent
    return list(reversed(out))

def nearest(grid,cur,targets,blocked=set()):
    q=deque([cur]); prev={cur:(None,None)}; found=None
    while q:
        p=q.popleft()
        if p in targets and p!=cur:
            found=p; break
        for n,d in neighbors(grid,p,blocked):
            if n not in prev:
                prev[n]=(p,d); q.append(n)
    if found is None: return None,None
    out=[]; p=found
    while p!=cur:
        parent,d=prev[p]; out.append((p,d)); p=parent
    return found,list(reversed(out))

def build_route(grid):
    pellets={p for p,c in grid.items() if c in ".O"}
    unvisited=set(pellets)
    cur=(14,23); unvisited.discard(cur); route=[]
    for i,(power,target_idx) in enumerate(zip(POWER_SEQUENCE,POWER_TARGET_INDICES)):
        locked=set(POWER_SEQUENCE[i:])
        while len(route)<target_idx-10:
            targets=unvisited-locked
            if not targets: break
            target,path=nearest(grid,cur,targets,locked)
            if not path or len(route)+len(path)>target_idx-10: break
            for p,d in path:
                route.append((p,d)); unvisited.discard(p)
            cur=target
        path=shortest(grid,cur,power,set(POWER_SEQUENCE[i+1:]))
        if path is None: raise SystemExit(f"No path to power {power}")
        for p,d in path:
            route.append((p,d)); unvisited.discard(p)
        cur=power
    while unvisited:
        target,path=nearest(grid,cur,unvisited,set())
        if not path: raise SystemExit(f"Unreachable pellets remain: {len(unvisited)}")
        for p,d in path:
            route.append((p,d)); unvisited.discard(p)
        cur=target
    return route,pellets

def schedule(grid,route,pellets,base_frame=112):
    visible=set(pellets); pause_count=0; cur=(14,23); frame=base_frame
    events=[{"frame":21,"order":0,"type":"mouse_click","x":180,"y":276,"button":1}]
    last=None
    powers=[]
    for index,(dest,direction) in enumerate(route):
        if direction!=last:
            events.append({"frame":frame,"order":0,"type":"key_down","key":direction})
            events.append({"frame":frame+1,"order":0,"type":"key_up","key":direction})
            last=direction
        if cur in visible:
            visible.remove(cur); duration=3
        else:
            pause_count+=1
            duration=3 if pause_count%2 else 2
        frame+=duration
        cur=dest
        if grid[cur]=="O":
            powers.append({"route_step":index+1,"cell":[cur[0],cur[1]],"arrival_frame":frame})
    if cur in visible: visible.remove(cur)
    if visible: raise SystemExit(f"Route missed {len(visible)} pellets")
    return events,frame,powers

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True)
    ap.add_argument("--out",required=True)
    args=ap.parse_args()
    grid=parse_maze(args.source)
    route,pellets=build_route(grid)
    events,last_frame,powers=schedule(grid,route,pellets)
    data={
      "name":"level_clear_route",
      "classification":"RNG",
      "fps":21,
      "duration_seconds":max(62,int(last_frame/21)+8),
      "notes":"Fixed source-derived route visits all 244 pellet/power cells. Route mechanics are deterministic, but full-run survival is exposed to ghost random(); use only successful runs as observable level-clear references, never as a pixel-exact ghost oracle.",
      "source_route":{
        "start":[14,23],"pellet_cells":len(pellets),"route_steps":len(route),
        "planned_last_pellet_frame":last_frame,"power_visits":powers,
        "score_from_pellets_only":sum(50 if grid[p]=="O" else 10 for p in pellets)
      },
      "events":events
    }
    Path(args.out).parent.mkdir(parents=True,exist_ok=True)
    Path(args.out).write_text(json.dumps(data,indent=2)+"\n","utf-8")
    print(json.dumps(data["source_route"],indent=2))

if __name__=="__main__": main()
