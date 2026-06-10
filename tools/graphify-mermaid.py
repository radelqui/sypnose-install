#!/usr/bin/env python3
"""graphify-mermaid — exporta graphify-out/graph.json a Mermaid (graph.mmd).

Parte de /sypnose -> /registry -> /graphify.
Uso:
    python3 tools/graphify-mermaid.py [graph.json] [-o graph.mmd] [--max 80] [--direction LR|TD]

Sin dependencias externas. Acepta el graph.json de graphify (nodes/edges) y tambien
formatos networkx node-link (nodes/links con source/target).
"""
import json
import re
import sys
import argparse
from collections import defaultdict

EDGE_STYLE = {
    "calls": "-->",
    "imports": "-->",
    "contains": "-->",
    "reads": "-.->|reads|",
    "writes": "-.->|writes|",
    "inferred": "-..->",
}

def nid(x: str) -> str:
    return "n_" + re.sub(r"[^A-Za-z0-9_]", "_", str(x))

def esc(label: str) -> str:
    return str(label).replace('"', "'").strip() or "?"

def load_graph(path: str):
    g = json.load(open(path, encoding="utf-8"))
    nodes = g.get("nodes", [])
    edges = g.get("edges") or g.get("links") or []
    norm_nodes = []
    for n in nodes:
        if isinstance(n, str):
            n = {"id": n}
        norm_nodes.append({
            "id": n.get("id") or n.get("name"),
            "label": n.get("label") or n.get("name") or n.get("id"),
            "type": (n.get("type") or n.get("kind") or "fn").lower(),
            "community": n.get("community", n.get("group", 0)),
        })
    norm_edges = []
    for e in edges:
        norm_edges.append({
            "src": e.get("src") or e.get("source"),
            "dst": e.get("dst") or e.get("target"),
            "rel": (e.get("rel") or e.get("relation") or e.get("type") or "calls").lower(),
        })
    return norm_nodes, norm_edges

def build(nodes, edges, max_nodes=80, direction="LR"):
    lines = [f"graph {direction}"]
    by_comm = defaultdict(list)
    for n in nodes:
        by_comm[n["community"]].append(n)

    kept = set()
    collapsed = set()
    budget = max_nodes
    for comm in sorted(by_comm, key=lambda c: -len(by_comm[c])):
        grp = by_comm[comm]
        if budget - len(grp) >= 0 or budget > 10:
            take = grp[: max(0, budget)]
            budget -= len(take)
            lines.append(f'  subgraph com{comm}["Comunidad {comm}"]')
            for nd in take:
                kept.add(nd["id"])
                if nd["type"] == "api":
                    shape = f'(["{esc(nd["label"])}"])'
                elif nd["type"] == "table":
                    shape = f'[("{esc(nd["label"])}")]'
                else:
                    shape = f'["{esc(nd["label"])}"]'
                lines.append(f"    {nid(nd['id'])}{shape}")
            lines.append("  end")
        else:
            collapsed.add(comm)
            lines.append(f'  com{comm}["Comunidad {comm} ({len(grp)} nodos)"]')

    node_comm = {n["id"]: n["community"] for n in nodes}
    seen = set()
    for e in edges:
        s, d = e["src"], e["dst"]
        if s is None or d is None:
            continue
        sref = nid(s) if s in kept else f"com{node_comm.get(s, 0)}"
        dref = nid(d) if d in kept else f"com{node_comm.get(d, 0)}"
        if sref == dref:
            continue
        arrow = EDGE_STYLE.get(e["rel"], "-->")
        key = (sref, dref, arrow)
        if key in seen:
            continue
        seen.add(key)
        lines.append(f"  {sref} {arrow} {dref}")
    return "\n".join(lines) + "\n"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("graph", nargs="?", default="graphify-out/graph.json")
    ap.add_argument("-o", "--out", default="graphify-out/graph.mmd")
    ap.add_argument("--max", type=int, default=80)
    ap.add_argument("--direction", choices=["LR", "TD"], default="LR")
    a = ap.parse_args()
    nodes, edges = load_graph(a.graph)
    out = build(nodes, edges, a.max, a.direction)
    if not out.startswith("graph "):
        print("[graphify-mermaid] ERROR: salida invalida", file=sys.stderr)
        sys.exit(1)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(out)
    print(f"[graphify-mermaid] OK -> {a.out} ({len(nodes)} nodos, {len(edges)} aristas)")

if __name__ == "__main__":
    main()
