"""report_graphs — the graph-theoretic views in the balance report.

Three graphs per kit, each computed here and drawn by report_template.html:

  mod_network   Class-mod synergy graph. Nodes are the kit's 8 mods; the weight of edge (i, j) is
                the PAIRWISE INTERACTION of the two mods — how much they add together beyond their
                separate effects — fitted by least squares over every measured 3-mod loadout:

                    log v(S) = Σ_{i∈S} a_i + Σ_{i<j∈S} b_ij + ε          (S = a loadout)

                with the 8 single-mod runs pinning each a_i. 8 solo terms + 28 pair terms against
                64 measurements; a light ridge on b keeps the fit stable. What the pairwise model
                cannot explain (true three-way effects + noise) is reported as R², so the reader
                knows how far to trust the edges. Mod evolutions (ClassModData.EVOLUTIONS) are
                pairs, so they should show up as strong edges — a built-in validity check.

                Node order on the circle comes from spectral seriation: sort by the Fiedler vector
                (2nd eigenvector of the Laplacian of |b|). Strongly linked mods land next to each
                other, which minimises long chords crossing the circle.

  dep_graph     Prerequisite DAG: ingredients → evolutions / capstones, layered by longest path
                from a source (Sugiyama-style), with each edge's multiplicity ("Might ×2") and each
                node's measured value. Within-layer order uses the barycenter heuristic to cut
                crossings.

  (search trace) The greedy optimizer's per-step candidates are already in the greedy stage
                output; the template draws them directly.

All values are kept as log-ratios for offense and defense separately, so the page can re-weight
them live with the Offense/Survival control without refitting anything.
"""
from __future__ import annotations

import itertools
import math

import numpy as np

RIDGE = 0.1   # on the pair terms only; units are (log-ratio)², tiny next to 56 loadout equations


def _log(x):
    return math.log(x) if x and x > 0 else None


def mod_network(mods_kit: dict, ch: dict) -> dict | None:
    singles = mods_kit.get("singles", [])
    loads = mods_kit.get("loadouts", [])
    ids = [m["id"] for m in ch["mods"]]
    if len(singles) < 3 or len(loads) < 10:
        return None
    idx = {m: i for i, m in enumerate(ids)}
    pairs = list(itertools.combinations(range(len(ids)), 2))
    pidx = {p: len(ids) + k for k, p in enumerate(pairs)}
    nvar = len(ids) + len(pairs)

    def fit(metric: str):
        rows, ys, ws = [], [], []
        for r in singles:
            y = _log(r["compare"].get(metric))
            if y is None or r["mod"] not in idx:
                continue
            row = np.zeros(nvar)
            row[idx[r["mod"]]] = 1
            rows.append(row); ys.append(y); ws.append(2.0)   # singles ran on 3x the seeds
        tri_rows = []
        for r in loads:
            y = _log(r["compare"].get(metric))
            ms = [idx[m] for m in r["mods"] if m in idx]
            if y is None or len(ms) != len(r["mods"]):
                continue
            row = np.zeros(nvar)
            for i in ms:
                row[i] = 1
            for i, j in itertools.combinations(sorted(ms), 2):
                row[pidx[(i, j)]] = 1
            rows.append(row); ys.append(y); ws.append(1.0)
            tri_rows.append(len(rows) - 1)
        if len(rows) < nvar // 2:
            return None
        A = np.array(rows) * np.sqrt(np.array(ws))[:, None]
        b = np.array(ys) * np.sqrt(np.array(ws))
        ridge = np.zeros((len(pairs), nvar))
        for k in range(len(pairs)):
            ridge[k, len(ids) + k] = math.sqrt(RIDGE)
        A2 = np.vstack([A, ridge])
        b2 = np.concatenate([b, np.zeros(len(pairs))])
        x, *_ = np.linalg.lstsq(A2, b2, rcond=None)
        pred = np.array(rows) @ x
        yt = np.array(ys)[tri_rows]
        pt = pred[tri_rows]
        sst = float(((yt - yt.mean()) ** 2).sum())
        ssr = float(((yt - pt) ** 2).sum())
        r2 = 1 - ssr / sst if sst > 0 else None
        rmse = math.sqrt(ssr / max(len(tri_rows), 1))
        return x, r2, rmse

    fo, fd = fit("offense"), fit("defense")   # raw composites: shrinkage would bias a fit
    if fo is None:
        return None
    xo, r2o, rmseo = fo
    xd, r2d, rmsed = fd if fd else (np.zeros(nvar), None, None)

    evo_pairs = {}
    for e in ch.get("mod_evolutions", []):
        req = e.get("requires", [])
        if len(req) == 2 and all(m in idx for m in req):
            i, j = sorted(idx[m] for m in req)
            evo_pairs[(i, j)] = e["name"].title() if e["name"].isupper() else e["name"]

    # Spectral seriation for the circular order: Fiedler vector of the |b| Laplacian.
    W = np.zeros((len(ids), len(ids)))
    for (i, j), k in pidx.items():
        w = abs(xo[k]) + abs(xd[k])
        W[i, j] = W[j, i] = w
    L = np.diag(W.sum(1)) - W
    try:
        vals, vecs = np.linalg.eigh(L)
        fiedler = vecs[:, 1] if len(vals) > 1 else np.arange(len(ids))
        order = [ids[i] for i in np.argsort(fiedler)]
    except np.linalg.LinAlgError:
        order = ids

    names = {m["id"]: (m["name"].title() if m["name"].isupper() else m["name"]) for m in ch["mods"]}
    nodes = [{"id": m, "name": names[m], "off": float(xo[idx[m]]), "def": float(xd[idx[m]])} for m in ids]
    edges = [{"a": ids[i], "b": ids[j], "off": float(xo[k]), "def": float(xd[k]),
              "evo": evo_pairs.get((i, j))} for (i, j), k in pidx.items()]
    return {"nodes": nodes, "edges": edges, "order": order,
            "fit": {"r2_off": r2o, "r2_def": r2d, "rmse_off": rmseo, "rmse_def": rmsed,
                    "n_loadouts": len(loads)}}


def dep_graph(picks_kit: dict, ch: dict, cat: dict) -> dict | None:
    """Ingredient → target DAG for evolutions and capstones, with measured values."""
    rows = {r["id"]: r for r in picks_kit.get("picks", [])}
    reqs = {}
    for u in ch["ability_upgrades"]:
        if u["requires"]:
            reqs[u["id"]] = list(u["requires"])
    for e in cat["evolutions"]:
        if e["id"] in rows:
            reqs[e["id"]] = list(e["requires"])
    if not reqs:
        return None
    node_ids = set(reqs)
    for r in reqs.values():
        node_ids.update(r)

    # Layer = longest path from a source.
    layer: dict = {}

    def depth(n, seen=()):
        if n in layer:
            return layer[n]
        if n not in reqs or n in seen:
            layer[n] = 0
            return 0
        layer[n] = 1 + max(depth(p, seen + (n,)) for p in set(reqs[n]))
        return layer[n]

    for n in node_ids:
        depth(n)

    def val(n):
        r = rows.get(n)
        if not r:
            return None, None
        sh = r.get("shrunk") or {}
        return _log(sh.get("offense") or r["compare"].get("offense")), \
            _log(sh.get("defense") or r["compare"].get("defense"))

    chains = picks_kit.get("chains", {})
    nodes = []
    for n in node_ids:
        vo, vd = val(n)
        prereq = rows.get(n, {}).get("prereq", [])
        ch_c = chains.get("+".join(prereq)) if prereq else None
        nodes.append({"id": n, "layer": layer[n], "off": vo, "def": vd,
                      "kind": rows.get(n, {}).get("kind", "generic"),
                      "chain_off": _log(ch_c["offense"]) if ch_c else None,
                      "chain_def": _log(ch_c["defense"]) if ch_c else None,
                      "prereq": prereq})
    edges = []
    for t, rs in reqs.items():
        for p in sorted(set(rs)):
            edges.append({"from": p, "to": t, "mult": rs.count(p)})

    # Barycenter ordering, two sweeps down and up.
    layers: dict = {}
    for nd in nodes:
        layers.setdefault(nd["layer"], []).append(nd["id"])
    for l in layers:
        layers[l].sort()
    pos = {n: i for l in layers for i, n in enumerate(layers[l])}
    for _ in range(4):
        for l in sorted(layers)[1:]:
            layers[l].sort(key=lambda n: _bary(n, edges, pos, incoming=True))
            pos.update({n: i for i, n in enumerate(layers[l])})
        for l in sorted(layers, reverse=True)[1:]:
            layers[l].sort(key=lambda n: _bary(n, edges, pos, incoming=False))
            pos.update({n: i for i, n in enumerate(layers[l])})
    for nd in nodes:
        nd["pos"] = pos[nd["id"]]
    return {"nodes": nodes, "edges": edges, "layers": {str(k): v for k, v in layers.items()}}


def _bary(n, edges, pos, incoming: bool) -> float:
    nb = [pos[e["from"]] for e in edges if e["to"] == n] if incoming else \
         [pos[e["to"]] for e in edges if e["from"] == n]
    return sum(nb) / len(nb) if nb else pos.get(n, 0)
