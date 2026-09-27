"""sim_stages — the balance experiments, built on simctl.run().

    python tools/sim/sim_stages.py catalog      # dump live content lists
    python tools/sim/sim_stages.py calibrate    # find each kit's best play policy per arena
    python tools/sim/sim_stages.py baseline     # level-1 kit profiles (hero comparison)
    python tools/sim/sim_stages.py picks        # marginal value of every level-up pick
    python tools/sim/sim_stages.py mods         # class-mod singles + every 3-mod loadout
    python tools/sim/sim_stages.py greedy       # best 8-pick build per kit
    python tools/sim/sim_stages.py all

Every stage writes tools/sim/out/stages/<stage>.json. Stages read earlier stages' files, so they
run in the order above; all scenario results are cached (simctl), so re-running a stage after a
report tweak is free and after a code change re-measures exactly what changed.

── What the numbers mean (read before trusting any of them) ──────────────────────────────────
  single    sustained DPS on one rooted immortal dummy, starting at the policy's range
  cluster   summed DPS on 6 rooted immortal dummies packed within 24px
  horde     kills/min against clumped packs of chasing 60-HP fodder (player immune)
  pressure  seconds until the first would-be death (capped 180) in a brawl against the real
            enemy mix, hitting back, spawn count and difficulty both ramping, no escape-kiting —
            the only arena where defence counts

A "policy" is how the bot plays the kit: rotation (which buttons, in which pattern), skill use,
and preferred distance. It is chosen PER KIT PER ARENA by search (calibrate), because a fixed
policy would measure how well that policy suits the kit instead of how strong the kit is.

Ratios compare against the same kit with no picks/mods, SAME seeds, SAME policies (common random
numbers). Every ratio carries a bootstrap 95% CI over seeds; a CI that straddles 1.0 is reported
as "no measurable effect", not ranked.
"""
from __future__ import annotations

import itertools
import json
import math
import random
import statistics as st
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from simctl import GODOT, OUT, ROOT, code_fingerprint, run  # noqa: E402

STAGES = OUT / "stages"
STAGES.mkdir(parents=True, exist_ok=True)

ROTATIONS = [("L", None), ("H", None), ("L1H", None), ("L2H", None), ("L3H", None),
             ("C", 1.5), ("C", 3.0), ("W", 1.5)]
SKILLS = ["none", "q", "e", "qe", "qed", "e_once_q"]
RANGES = [16, 28, 48, 80, 120, 170]

DUR = {"single": 30.0, "cluster": 30.0, "horde": 40.0, "pressure": 180.0}
GRID_DUR = 20.0
HORDE_HP = 60.0
METRIC = {"single": "dps", "cluster": "dps", "horde": "kills_per_min", "pressure": "seconds"}
ARENAS = ["single", "cluster", "horde", "pressure"]


# ─── plumbing ─────────────────────────────────────────────────────────────────

def save(name: str, data) -> Path:
    p = STAGES / f"{name}.json"
    p.write_text(json.dumps(data, indent=1), encoding="utf-8")
    return p


def load(name: str):
    p = STAGES / f"{name}.json"
    if not p.exists():
        raise SystemExit(f"stage '{name}' has not been run yet ({p})")
    return json.loads(p.read_text(encoding="utf-8"))


def catalog() -> dict:
    p = STAGES / "catalog.json"
    fp = code_fingerprint()
    if p.exists():
        c = json.loads(p.read_text(encoding="utf-8"))
        if c.get("_fp") == fp:
            return c
    cmd = [str(GODOT), "--headless", "--path", str(ROOT), "--script",
           "res://tools/sim/sim_catalog.gd", "--", "--sim", f"--out={p}"]
    subprocess.run(cmd, capture_output=True, timeout=120)
    c = json.loads(p.read_text(encoding="utf-8"))
    c["_fp"] = fp
    p.write_text(json.dumps(c, indent=1), encoding="utf-8")
    return c


def policy(rotation: str, hold, skills: str, rng: float) -> dict:
    p = {"rotation": rotation, "skills": skills, "range": rng}
    if hold is not None:
        p["hold"] = hold
    return p


def pol_key(p: dict) -> str:
    h = f"@{p['hold']}" if "hold" in p else ""
    return f"{p['rotation']}{h}/{p['skills']}/{int(p['range'])}"


def scenario(char: str, arena: str, pol: dict, seed: int, upgrades=None, mods=None,
             duration: float | None = None, tag: str = "") -> dict:
    sc = {"id": f"{tag}|{char}|{arena}|{pol_key(pol)}|{seed}", "character": char, "arena": arena,
          "seed": seed, "duration": duration if duration is not None else DUR[arena]}
    sc.update(pol)
    if arena == "horde":
        sc["enemy_hp"] = HORDE_HP
    if upgrades:
        sc["upgrades"] = list(upgrades)
    if mods:
        sc["mods"] = list(mods)
    return sc


def metric(r: dict, arena: str) -> float:
    return float(r[METRIC[arena]])


def mean(xs):
    return sum(xs) / len(xs) if xs else 0.0


def boot_ratio(xs: list[float], ys: list[float], stat="mean", n: int = 2000,
               seed: int = 7) -> tuple[float, float, float]:
    """Ratio stat(ys)/stat(xs) with a paired bootstrap 95% CI over seeds.

    Paired because both lists come from the SAME seeds (common random numbers): resampling seed
    indices jointly keeps that pairing, which is what makes small effects resolvable at all."""
    f = (lambda v: sum(v) / len(v)) if stat == "mean" else st.median
    base = f(xs)
    if base <= 0:
        return (float("nan"),) * 3
    r = f(ys) / base
    rnd = random.Random(seed)
    k = len(xs)
    rs = []
    for _ in range(n):
        idx = [rnd.randrange(k) for _ in range(k)]
        bx = f([xs[i] for i in idx])
        by = f([ys[i] for i in idx])
        if bx > 0:
            rs.append(by / bx)
    rs.sort()
    lo = rs[int(0.025 * len(rs))] if rs else r
    hi = rs[int(0.975 * len(rs)) - 1] if rs else r
    return r, lo, hi


def _ln(x: float) -> float:
    return math.log(x) if x and x > 0 and not math.isnan(x) else float("nan")


def _se(lo: float, hi: float) -> float:
    """Standard error in log space, read back off a 95% interval."""
    if not (lo and hi and lo > 0 and hi > 0) or math.isnan(lo) or math.isnan(hi):
        return float("nan")
    return (math.log(hi) - math.log(lo)) / (2 * 1.96)


## ── Empirical-Bayes shrinkage ────────────────────────────────────────────────
## Ranking by raw point estimates lets the noisiest arena decide the order: survival's 95%
## interval is still ±20-30% at 6 seeds, so a pick whose survival happened to read -19% on those
## seeds sank to the bottom of the table on noise alone.
##
## Each arena's log-ratio l (standard error s) is shrunk under a SPIKE-AND-SLAB prior fitted to
## all of the kit's picks by EM: with probability 1-π the true effect is zero (spike), otherwise
## it is N(0, τ²) (slab). The posterior mean is  P(slab | l) · l · τ² / (τ² + s²).
## A single normal prior was tried first and rejected: most picks barely move survival, so τ²
## came out tiny and a genuinely large, clearly significant effect (Bloodthirst: +80%, 95% CI
## +18..+134%) was flattened to +5%. The mixture lets a clear outlier keep most of its size while
## noise around zero still collapses to zero. Raw ratios and intervals are what tables display.
S_FLOOR = 0.005   # a deterministic arena has s≈0; floor it so the spike density stays finite


def _npdf(x: float, var: float) -> float:
    return math.exp(-x * x / (2 * var)) / math.sqrt(2 * math.pi * var)


def eb_priors(compares: list[dict]) -> dict:
    pri = {}
    for a in ARENAS:
        pts = [(c["arenas"][a]["log"], max(c["arenas"][a]["se"], S_FLOOR)) for c in compares
               if a in c["arenas"] and not math.isnan(c["arenas"][a].get("log", float("nan")))
               and not math.isnan(c["arenas"][a].get("se", float("nan")))]
        if len(pts) < 5:
            pri[a] = None   # too few to fit a prior: no shrinkage
            continue
        pi = 0.5
        tau2 = max(mean([l * l for l, _ in pts]), 1e-4)
        for _ in range(300):
            ps = []
            for l, se in pts:
                slab = pi * _npdf(l, tau2 + se * se)
                spike = (1 - pi) * _npdf(l, se * se)
                ps.append(slab / (slab + spike) if slab + spike > 0 else 1.0)
            pi = min(max(mean(ps), 0.02), 0.98)
            w = [p / (tau2 + se * se) ** 2 for p, (_, se) in zip(ps, pts)]
            num = sum(wi * (l * l - se * se) for wi, (l, se) in zip(w, pts))
            den = sum(w)
            tau2 = max(num / den if den > 0 else tau2, 1e-5)
        pri[a] = {"pi": pi, "tau2": tau2}
    return pri


def shrunk(c: dict, priors: dict) -> dict:
    """Composite offense / defense / overall from shrunk per-arena log-ratios."""
    sh = {}
    for a, v in c["arenas"].items():
        l, se = v.get("log", float("nan")), v.get("se", float("nan"))
        if math.isnan(l):
            continue
        p = priors.get(a)
        if not isinstance(p, dict) or math.isnan(se):
            sh[a] = l
            continue
        s2 = max(se, S_FLOOR) ** 2
        slab = p["pi"] * _npdf(l, p["tau2"] + s2)
        spike = (1 - p["pi"]) * _npdf(l, s2)
        post = slab / (slab + spike) if slab + spike > 0 else 1.0
        sh[a] = post * l * p["tau2"] / (p["tau2"] + s2)
    off = [sh[a] for a in ("single", "cluster", "horde") if a in sh]
    offense = math.exp(mean(off)) if off else float("nan")
    defense = math.exp(sh["pressure"]) if "pressure" in sh else float("nan")
    overall = math.sqrt(offense * defense) if offense > 0 and defense > 0 else float("nan")
    return {"offense": offense, "defense": defense, "overall": overall,
            "arenas": {a: math.exp(x) for a, x in sh.items()}}


def verdict(r: float, lo: float, hi: float) -> str:
    if math.isnan(r):
        return "n/a"
    if lo > 1.0:
        return "up"
    if hi < 1.0:
        return "down"
    return "flat"


def chars(cat: dict, only: list[str] | None = None) -> list[dict]:
    out = cat["characters"]
    if only:
        out = [c for c in out if c["id"] in only or c["kit"] in only]
    return out


# ─── stage: calibrate ─────────────────────────────────────────────────────────

def stage_calibrate(only=None, workers=None):
    """Search each kit's play policy per arena. Grid → refine top 8 with 3 seeds → pick."""
    cat = catalog()
    cs = chars(cat, only)
    grid_pols = [policy(r, h, s, rg) for (r, h) in ROTATIONS for s in SKILLS for rg in RANGES]
    kw = {"workers": workers} if workers else {}

    # 1) coarse grid, one seed, short
    scs = [scenario(c["id"], a, p, 1, duration=GRID_DUR, tag="grid")
           for c in cs for a in ("single", "cluster") for p in grid_pols]
    res = run(scs, label="cal-grid", **kw)
    grid: dict = {}
    for sc, r in zip(scs, res):
        grid.setdefault(sc["character"], {}).setdefault(sc["arena"], []).append(
            (metric(r, sc["arena"]), sc, r))

    # 2) refine the top 8 per (kit, arena) with 3 full-length seeds
    ref_scs = []
    for c in cs:
        for a in ("single", "cluster"):
            top = sorted(grid[c["id"]][a], key=lambda t: -t[0])[:8]
            for _, sc, _ in top:
                pol = {k: sc[k] for k in ("rotation", "skills", "range", "hold") if k in sc}
                for seed in (1, 2, 3):
                    ref_scs.append(scenario(c["id"], a, pol, seed, tag="ref"))
    ref = run(ref_scs, label="cal-refine", **kw)
    ranked: dict = {}
    agg: dict = {}
    for sc, r in zip(ref_scs, ref):
        k = (sc["character"], sc["arena"], pol_key(sc))
        agg.setdefault(k, {"pol": {x: sc[x] for x in ("rotation", "skills", "range", "hold") if x in sc},
                           "vals": [], "results": []})
        agg[k]["vals"].append(metric(r, sc["arena"]))
        agg[k]["results"].append(r)
    for (ch, a, pk), d in agg.items():
        ranked.setdefault(ch, {}).setdefault(a, []).append({
            "policy": d["pol"], "key": pk, "mean": mean(d["vals"]), "vals": d["vals"],
            "by_ability": _merge_by_ability(d["results"]),
            "pilot": d["results"][0].get("pilot", {}), "warnings": sorted(set(
                w for rr in d["results"] for w in rr.get("warnings", [])))})
    for ch in ranked:
        for a in ranked[ch]:
            ranked[ch][a].sort(key=lambda x: -x["mean"])

    # 3) horde: best cluster + single policies, 3 seeds, rank by kills/min
    h_scs = []
    for c in cs:
        cands = _dedupe([x["policy"] for x in ranked[c["id"]]["cluster"][:6]] +
                        [x["policy"] for x in ranked[c["id"]]["single"][:3]])
        for pol in cands:
            for seed in (1, 2, 3):
                h_scs.append(scenario(c["id"], "horde", pol, seed, tag="hcal"))
    hres = run(h_scs, label="cal-horde", **kw)
    _rank_into(ranked, h_scs, hres, "horde")

    # 4) pressure (brawl): best 3 horde policies at their own range and two longer ones, 6 seeds
    p_scs = []
    for c in cs:
        cands = []
        for x in ranked[c["id"]]["horde"][:3]:
            for rg in (x["policy"]["range"], 60, 110):
                p = dict(x["policy"])
                p["range"] = rg
                cands.append(p)
        for pol in _dedupe(cands):
            for seed in range(1, 7):
                p_scs.append(scenario(c["id"], "pressure", pol, seed, tag="pcal"))
    pres = run(p_scs, label="cal-pressure", **kw)
    _rank_into(ranked, p_scs, pres, "pressure", stat="median")

    out = {"_fp": code_fingerprint(), "grid_size": len(grid_pols), "kits": {}}
    for c in cs:
        out["kits"][c["id"]] = {a: ranked[c["id"]][a][:10] for a in ARENAS}
        out["kits"][c["id"]]["grid"] = {
            a: [{"key": pol_key({k: sc[k] for k in ("rotation", "skills", "range", "hold") if k in sc}),
                 "value": v} for v, sc, _ in grid[c["id"]][a]] for a in ("single", "cluster")}
    old = _load_or(STAGES / "calibrate.json", {"kits": {}})
    old["kits"].update(out["kits"])
    out["kits"] = old["kits"]
    save("calibrate", out)
    return out


def _load_or(p: Path, default):
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else default


def _dedupe(pols: list[dict]) -> list[dict]:
    seen, out = set(), []
    for p in pols:
        k = pol_key(p)
        if k not in seen:
            seen.add(k)
            out.append(p)
    return out


def _merge_by_ability(results: list[dict]) -> dict:
    tot: dict = {}
    for r in results:
        for k, v in r.get("by_ability", {}).items():
            tot[k] = tot.get(k, 0.0) + float(v["damage"]) / len(results)
    return tot


def _rank_into(ranked: dict, scs: list[dict], res: list[dict], arena: str, stat: str = "mean"):
    agg: dict = {}
    for sc, r in zip(scs, res):
        k = (sc["character"], pol_key(sc))
        agg.setdefault(k, {"pol": {x: sc[x] for x in ("rotation", "skills", "range", "hold") if x in sc},
                           "vals": [], "results": []})
        agg[k]["vals"].append(metric(r, arena))
        agg[k]["results"].append(r)
    for (ch, pk), d in agg.items():
        f = st.median if stat == "median" else mean
        ranked.setdefault(ch, {}).setdefault(arena, []).append({
            "policy": d["pol"], "key": pk, "mean": f(d["vals"]), "vals": d["vals"],
            "by_ability": _merge_by_ability(d["results"]),
            "warnings": sorted(set(w for rr in d["results"] for w in rr.get("warnings", [])))})
    for ch in ranked:
        if arena in ranked[ch]:
            ranked[ch][arena].sort(key=lambda x: -x["mean"])


# ─── measurement of a build (shared by baseline / picks / mods / greedy) ─────

## How hard to look at one build. Seeds are 1..n in every arena, identical across builds, so any
## two builds measured with the same plan are paired seed-for-seed.
PLAN_FULL = {"single": (2, 6), "cluster": (2, 6), "horde": (1, 6), "pressure": (1, 8)}
PLAN_LIGHT = {"single": (1, 4), "cluster": (1, 4), "horde": (1, 4), "pressure": (1, 5)}
PLAN_BASE = {"single": (3, 3), "cluster": (3, 3), "horde": (1, 6), "pressure": (1, 10)}
## (top-N calibrated policies to try, seeds). Seed counts were raised 2026-09-26 after the pooled
## variance came in: dummy arenas vary ~3-4% run to run (crits), so 2 seeds could not resolve a
## +5% pick like Precision. Dummy runs are the cheapest in the sweep, so they get the most seeds.
## (top-N calibrated policies to try, seeds). For single/cluster the build is credited with its
## BEST policy of the top N — a pick that makes a different rotation optimal must get that credit.


def build_scenarios(cal: dict, char: str, upgrades, mods, plan: dict, tag: str) -> list[dict]:
    scs = []
    for a in ARENAS:
        npol, nseed = plan[a]
        for x in cal["kits"][char][a][:npol]:
            for seed in range(1, nseed + 1):
                scs.append(scenario(char, a, x["policy"], seed, upgrades, mods, tag=tag))
    return scs


def summarize(scs: list[dict], res: list[dict]) -> dict:
    """{arena: {"policy": key, "vals": [per-seed], "value": mean|median, ...}} using each arena's
    best policy (by mean over the same seeds)."""
    by: dict = {}
    crashed = []
    for sc, r in zip(scs, res):
        if r.get("crashed"):
            crashed.append({"scenario": sc["id"], "error": r.get("error", ""), "cause": r.get("cause", "")})
            continue
        by.setdefault(sc["arena"], {}).setdefault(pol_key(sc), []).append((sc["seed"], r))
    out = {}
    if crashed:
        ## A build that hangs or overflows the engine is a finding in its own right (see simctl's
        ## runaway note); it is excluded from every comparison rather than scored on what's left.
        out["_crashed"] = crashed
    for a, pols in by.items():
        best_k, best_v, best_rows = None, -1.0, None
        for k, rows in pols.items():
            rows.sort(key=lambda t: t[0])
            vals = [metric(r, a) for _, r in rows]
            v = st.median(vals) if a == "pressure" else mean(vals)
            if v > best_v:
                best_k, best_v, best_rows = k, v, rows
        vals = [metric(r, a) for _, r in best_rows]
        rs = [r for _, r in best_rows]
        out[a] = {"policy": best_k, "vals": vals, "value": best_v,
                  "dtps": mean([r["dtps"] for r in rs]),
                  "kills": mean([r["kills"] for r in rs]),
                  "by_ability": _merge_by_ability(rs),
                  "warnings": sorted(set(w for r in rs for w in r.get("warnings", []))),
                  "stats": rs[0].get("level_stats", {}),
                  "applied": rs[0].get("applied_upgrades", []),
                  "active_mods": rs[0].get("active_mods", [])}
    return out


## ── Intervals: pooled seed variance ──────────────────────────────────────────
## A build is run on only 2-6 seeds per arena, and a bootstrap over 2 values badly understates
## the noise: crit rolls alone move a 30 s dummy run by several percent (more for the Spark,
## whose crits are 3.25x), so a pure-HP pick read as "-6% pack DPS, significant". The per-run
## noise is a property of the kit and the arena, not of the pick, so it is estimated ONCE from
## every build of that kit together (hundreds of runs) -- the classic pooled within-group
## variance, on log values -- and every comparison's interval comes from it.
def pooled_var(summaries: list[dict]) -> dict:
    out = {}
    for a in ARENAS:
        num, dof = 0.0, 0
        for s in summaries:
            if a not in s:
                continue
            ls = [math.log(max(v, 1e-6)) for v in s[a]["vals"]]
            if len(ls) < 2:
                continue
            m = mean(ls)
            num += sum((x - m) ** 2 for x in ls)
            dof += len(ls) - 1
        if dof >= 4:
            out[a] = {"var": num / dof, "dof": dof}
    return out


## A median of n draws has ~pi/2 the variance of the mean (normal approx.); survival uses medians.
MEDIAN_EFF = math.pi / 2


def compare(base: dict, cand: dict, pooled: dict | None = None) -> dict:
    """Per-arena ratios with 95% intervals (pooled variance when given, else paired bootstrap)
    + composite indices."""
    out = {}
    for a in ARENAS:
        if a not in base or a not in cand:
            continue
        n = min(len(base[a]["vals"]), len(cand[a]["vals"]))
        stat = "median" if a == "pressure" else "mean"
        if pooled and a in pooled:
            bx, cx = base[a]["vals"], cand[a]["vals"]
            f = st.median if stat == "median" else mean
            r = f(cx) / f(bx) if f(bx) > 0 else float("nan")
            v = pooled[a]["var"] * (MEDIAN_EFF if stat == "median" else 1.0)
            se = math.sqrt(v / len(bx) + v / len(cx))
            l = _ln(r)
            lo, hi = (math.exp(l - 1.96 * se), math.exp(l + 1.96 * se)) if not math.isnan(l) else (l, l)
        else:
            r, lo, hi = boot_ratio(base[a]["vals"][:n], cand[a]["vals"][:n], stat)
            se = _se(lo, hi)
        out[a] = {"ratio": r, "lo": lo, "hi": hi, "verdict": verdict(r, lo, hi),
                  "log": _ln(r), "se": se}
    off = [out[a]["ratio"] for a in ("single", "cluster", "horde") if a in out]
    offense = math.exp(mean([math.log(max(x, 1e-6)) for x in off])) if off else float("nan")
    defense = out.get("pressure", {}).get("ratio", float("nan"))
    overall = math.sqrt(offense * defense) if offense > 0 and defense > 0 else float("nan")
    return {"arenas": out, "offense": offense, "defense": defense, "overall": overall}


def measure_many(cal: dict, builds: list[dict], plan: dict, label: str, workers=None) -> list[dict]:
    """builds: [{"char", "upgrades", "mods", "key"}] → same list with "summary" filled."""
    all_scs, spans = [], []
    for b in builds:
        scs = build_scenarios(cal, b["char"], b.get("upgrades"), b.get("mods"), plan, label)
        spans.append((len(all_scs), len(scs)))
        all_scs += scs
    kw = {"workers": workers} if workers else {}
    res = run(all_scs, label=label, **kw)
    for b, (s0, n) in zip(builds, spans):
        b["summary"] = summarize(all_scs[s0:s0 + n], res[s0:s0 + n])
    return builds


# ─── stage: baseline ──────────────────────────────────────────────────────────

def stage_baseline(only=None, workers=None):
    cat, cal = catalog(), load("calibrate")
    builds = [{"char": c["id"], "key": "base"} for c in chars(cat, only) if c["id"] in cal["kits"]]
    measure_many(cal, builds, PLAN_BASE, "baseline", workers)
    out = _load_or(STAGES / "baseline.json", {"kits": {}})
    for b in builds:
        out["kits"][b["char"]] = b["summary"]
    out["_fp"] = code_fingerprint()
    save("baseline", out)
    return out


# ─── stage: picks ─────────────────────────────────────────────────────────────

def pick_candidates(cat: dict, ch: dict) -> list[dict]:
    """Every pick legal at level 1, plus conditional ones measured on top of their prerequisites.

    kind: generic | ability | capstone (ability w/ prerequisites) | evolution (generic recipe)
    `prereq` is the build the candidate is compared against (empty for level-1 picks)."""
    out = []
    for e in cat["pool"]:
        if e["requires_cap"] and e["requires_cap"] not in ch["caps"]:
            continue
        out.append({"id": e["id"], "name": e["name"], "kind": "generic", "role": e["role"],
                    "description": e["description"], "prereq": [], "max_rank": e["max_rank"]})
    for u in ch["ability_upgrades"]:
        if u["requires"]:
            out.append({"id": u["id"], "name": u["name"], "kind": "capstone", "role": "kit",
                        "description": u["description"], "prereq": list(u["requires"]),
                        "max_rank": u["max_rank"], "op": u["op"]})
        else:
            out.append({"id": u["id"], "name": u["name"], "kind": "ability", "role": "kit",
                        "description": u["description"], "prereq": [], "max_rank": u["max_rank"],
                        "op": u["op"]})
    for ev in cat["evolutions"]:
        ok = all(any(p["id"] == req and (not p["requires_cap"] or p["requires_cap"] in ch["caps"])
                     for p in cat["pool"]) for req in ev["requires"])
        if ok:
            out.append({"id": ev["id"], "name": ev["name"], "kind": "evolution", "role": "evolution",
                        "description": ev["description"], "prereq": list(ev["requires"]),
                        "max_rank": 1})
    ## Prerequisite chains can themselves have prerequisites (Skyfall needs Thunderhead needs
    ## Rolling Thunder x2): expand so the comparison build is actually legal.
    ups = {u["id"]: u for u in ch["ability_upgrades"]}
    for c in out:
        c["prereq"] = _expand_prereq(c["prereq"], ups)
    return out


def _expand_prereq(reqs: list[str], ups: dict) -> list[str]:
    """Flatten an ability upgrade's prerequisite chain into a legal pick order, e.g. Skyfall
    (needs Thunderhead, which needs Rolling Thunder x2) → [rolling, rolling, thunderhead]."""
    out: list[str] = []
    for r in reqs:
        if r in ups and ups[r]["requires"]:
            out += _expand_prereq(list(ups[r]["requires"]), ups)
        out.append(r)
    return out


def stage_picks(only=None, workers=None):
    cat, cal = catalog(), load("calibrate")
    out = _load_or(STAGES / "picks.json", {"kits": {}})
    for ch in chars(cat, only):
        if ch["id"] not in cal["kits"]:
            continue
        cands = pick_candidates(cat, ch)
        prereq_sets = {tuple(c["prereq"]) for c in cands}
        bases = {pr: {"char": ch["id"], "upgrades": list(pr), "key": "base:" + "+".join(pr)}
                 for pr in prereq_sets}
        builds = [{"char": ch["id"], "upgrades": c["prereq"] + [c["id"]], "key": c["id"]}
                  for c in cands]
        measure_many(cal, list(bases.values()) + builds, PLAN_FULL, f"picks-{ch['kit']}", workers)
        pooled = pooled_var([x["summary"] for x in list(bases.values()) + builds])
        rows = []
        for c, b in zip(cands, builds):
            base = bases[tuple(c["prereq"])]["summary"]
            cmp_ = compare(base, b["summary"], pooled)
            rows.append({**c, "compare": cmp_, "summary": b["summary"],
                         "applied_ok": b["summary"]["single"]["applied"] == b["upgrades"]})
        pri = eb_priors([r["compare"] for r in rows])
        for r in rows:
            r["shrunk"] = shrunk(r["compare"], pri)
        rows.sort(key=lambda r: -_nz(r["shrunk"]["overall"]))
        ## What each prerequisite SET is worth on its own, against the bare kit — the edges of the
        ## report's dependency graph need the chain's own value, not just the capstone's uplift.
        chains = {"+".join(pr): compare(bases[()]["summary"], bases[pr]["summary"], pooled)
                  for pr in bases if pr}
        out["kits"][ch["id"]] = {"picks": rows, "base": bases[()]["summary"], "priors": pri,
                                 "pooled": pooled, "chains": chains}
        save("picks", out)
    out["_fp"] = code_fingerprint()
    save("picks", out)
    return out


# ─── stage: mods ──────────────────────────────────────────────────────────────

def stage_mods(only=None, workers=None):
    cat, cal = catalog(), load("calibrate")
    out = _load_or(STAGES / "mods.json", {"kits": {}})
    for ch in chars(cat, only):
        if ch["id"] not in cal["kits"]:
            continue
        ids = [m["id"] for m in ch["mods"]]
        base = {"char": ch["id"], "mods": [], "key": "base"}
        singles = [{"char": ch["id"], "mods": [m], "key": m} for m in ids]
        measure_many(cal, [base] + singles, PLAN_FULL, f"mods1-{ch['kit']}", workers)
        combos = [{"char": ch["id"], "mods": list(t), "key": "+".join(t)}
                  for t in itertools.combinations(ids, cat["mod_slots"])]
        base_l = {"char": ch["id"], "mods": [], "key": "base"}
        measure_many(cal, [base_l] + combos, PLAN_LIGHT, f"mods3-{ch['kit']}", workers)
        pooled = pooled_var([x["summary"] for x in [base, base_l] + singles + combos])
        evos = {tuple(sorted(e["requires"])): e for e in ch["mod_evolutions"]}
        single_rows = []
        for s in singles:
            single_rows.append({"mod": s["mods"][0], "compare": compare(base["summary"], s["summary"], pooled),
                                "summary": s["summary"],
                                "active_ok": s["summary"]["single"]["active_mods"] == s["mods"]})
        combo_rows = []
        for cmb in combos:
            unlocked = [e["id"] for req, e in evos.items() if all(r in cmb["mods"] for r in req)]
            combo_rows.append({"mods": cmb["mods"], "evolutions": unlocked,
                               "compare": compare(base_l["summary"], cmb["summary"], pooled),
                               "summary": {a: {k: v for k, v in s.items() if k in ("value", "vals", "policy")}
                                           for a, s in cmb["summary"].items()},
                               "active_ok": sorted(cmb["summary"]["single"]["active_mods"]) == sorted(cmb["mods"])})
        for rows_ in (single_rows, combo_rows):
            pri = eb_priors([r["compare"] for r in rows_])
            for r in rows_:
                r["shrunk"] = shrunk(r["compare"], pri)
        single_rows.sort(key=lambda r: -_nz(r["shrunk"]["overall"]))
        combo_rows.sort(key=lambda r: -_nz(r["shrunk"]["overall"]))
        out["kits"][ch["id"]] = {"singles": single_rows, "loadouts": combo_rows,
                                 "base": base["summary"]}
        save("mods", out)
    out["_fp"] = code_fingerprint()
    save("mods", out)
    return out


def _nz(x: float) -> float:
    return -9.0 if (x is None or math.isnan(x)) else x


# ─── stage: greedy build optimizer ────────────────────────────────────────────

GREEDY_STEPS = 8
GREEDY_WIDTH = 8
## Picks the build search may not take. Static Discharge and Lightning Reflexes fire an on-crit AoE
## that can itself crit and re-fire synchronously, with no internal cooldown (StatusFactory) — past
## ~(enemies in 60 px) x (crit chance) = 1 the chain never ends and overflows the stack. The first
## full search (2026-09-27, kept as greedy_with_proc_chain.json) took Static Discharge by level 3 on
## every kit because near-runaway cascades inflate its damage, after which most crit picks crashed
## the engine (110 crashed runs across 5 kits). A best build measured on a runaway proc is not a
## best build, so both stay out of the search until the proc chain is fixed. Their level-1 values
## are still measured by the picks stage and flagged in the report.
## Fixed 2026-09-27 (TriggerComponent re-entrancy guard): a listener can no longer re-trigger
## itself, so the exclusion is lifted. Kept as an empty set so the mechanism stays for next time.
GREEDY_EXCLUDE: set[str] = set()


def legal_next(cat: dict, ch: dict, build: list[str]) -> list[str]:
    """Pick ids UpgradeManager.generate_choices could offer next, given `build` (in order),
    minus GREEDY_EXCLUDE."""
    ups = {u["id"]: u for u in ch["ability_upgrades"]}
    out = []
    for e in cat["pool"]:
        if e["requires_cap"] and e["requires_cap"] not in ch["caps"]:
            continue
        if build.count(e["id"]) < e["max_rank"]:
            out.append(e["id"])
    for u in ch["ability_upgrades"]:
        if build.count(u["id"]) >= u["max_rank"]:
            continue
        if all(build.count(r) >= u["requires"].count(r) for r in set(u["requires"])):
            out.append(u["id"])
    ## Generic evolutions strip their ingredients (UpgradeManager._apply_evolution), so a recipe
    ## is only on the table while every ingredient rank is still held.
    held = _held_after_evolutions(cat, build)
    for ev in cat["evolutions"]:
        if ev["id"] in build:
            continue
        if all(held.count(r) >= ev["requires"].count(r) for r in set(ev["requires"])):
            out.append(ev["id"])
    return [x for x in out if x not in GREEDY_EXCLUDE]


def _held_after_evolutions(cat: dict, build: list[str]) -> list[str]:
    held: list[str] = []
    evo = {e["id"]: e for e in cat["evolutions"]}
    for b in build:
        if b in evo:
            for r in evo[b]["requires"]:
                if r in held:
                    held.remove(r)
        else:
            held.append(b)
    return held


def stage_greedy(only=None, workers=None):
    cat, cal, picks = catalog(), load("calibrate"), load("picks")
    out = _load_or(STAGES / "greedy.json", {"kits": {}})
    for ch in chars(cat, only):
        if ch["id"] not in picks["kits"]:
            continue
        kp = picks["kits"][ch["id"]]
        prior = {r["id"]: _nz(r.get("shrunk", r["compare"])["overall"]) for r in kp["picks"]}
        ## Shrinkage prior for the greedy's own comparisons: the spread of pick effects this kit
        ## showed in the picks stage. With 8 candidates a step, a prior estimated from the step
        ## itself would be too unstable to trust.
        gpri = kp.get("priors") or eb_priors([r["compare"] for r in kp["picks"]])
        gpool = kp.get("pooled")
        build: list[str] = []
        base = {"char": ch["id"], "upgrades": [], "key": "base"}
        measure_many(cal, [base], PLAN_LIGHT, f"greedy-{ch['kit']}-0", workers)
        cur = base["summary"]
        steps = []
        for step in range(GREEDY_STEPS):
            legal = legal_next(cat, ch, build)
            ## Always keep evolutions and capstones in the beam — their level-1 prior is measured
            ## on top of prerequisites and does not rank fairly against a naked level-1 pick.
            evo_ids = {e["id"] for e in cat["evolutions"]}
            capstones = {u["id"] for u in ch["ability_upgrades"] if u["requires"]}
            special = [x for x in legal if x in evo_ids or x in capstones]
            ranked = sorted([x for x in legal if x not in special], key=lambda x: -prior.get(x, 0.0))
            beam = special + ranked[:max(1, GREEDY_WIDTH - len(special))]
            builds = [{"char": ch["id"], "upgrades": build + [x], "key": x} for x in beam]
            measure_many(cal, builds, PLAN_LIGHT, f"greedy-{ch['kit']}-{step + 1}", workers)
            scored = []
            crashed_here = [{"pick": b["key"], **b["summary"]["_crashed"][0]}
                            for b in builds if "_crashed" in b["summary"]]
            builds = [b for b in builds if "_crashed" not in b["summary"]]
            for b in builds:
                c = compare(cur, b["summary"], gpool)
                c["shrunk"] = shrunk(c, gpri)
                c_total = compare(base["summary"], b["summary"], gpool)
                c_total["shrunk"] = shrunk(c_total, gpri)
                scored.append((_nz(c["shrunk"]["overall"]), b, c, c_total))
            scored.sort(key=lambda t: -t[0])
            if not scored:
                ## Every candidate hung or crashed the engine: the build cannot be extended in
                ## this game build. Record it and stop the path here rather than guess.
                steps.append({"step": step + 1, "pick": None, "crashed": crashed_here,
                              "stopped": "every candidate crashed the engine"})
                out["kits"][ch["id"]] = {"build": build, "steps": steps, "final": cur,
                                         "base": base["summary"]}
                save("greedy", out)
                break
            best = scored[0]
            steps.append({"step": step + 1, "pick": best[1]["key"], "gain": best[2],
                          "crashed": crashed_here,
                          "cumulative": best[3],
                          "considered": [{"pick": s[1]["key"], "gain_overall": s[0],
                                          "gain": s[2]} for s in scored]})
            build = build + [best[1]["key"]]
            cur = best[1]["summary"]
            out["kits"][ch["id"]] = {"build": build, "steps": steps, "final": cur,
                                     "base": base["summary"]}
            save("greedy", out)
    out["_fp"] = code_fingerprint()
    save("greedy", out)
    return out


# ─── stage: recheck ───────────────────────────────────────────────────────────

## The 2026-09-26 upgrade-modifier fix touched exactly these: Vitality and Juggernaut carry the
## armor that used to be dead; Glass Cannon and Velocity consume Might, whose +15% damage the
## evolution strip used to leave behind.
RECHECK_IDS = ["vitality", "juggernaut", "glass_cannon", "velocity"]


def stage_recheck(only=None, workers=None, ids=None):
    """Re-measure a few picks after a targeted code fix, without re-running the whole sweep.

    Every cached result is keyed to the code fingerprint, so after a fix the old kit baselines no
    longer match the code either. This measures a FRESH baseline and each pick (on top of its own
    prerequisites) under the current code, then replaces those rows in picks.json. The rest of
    the table keeps its pre-fix measurements; a pick that does not touch the fixed code path
    measures the same either way. Added 2026-09-26 for the level-up armor fix (Vitality,
    Juggernaut: armor was filed under ("armor", "add"), which nothing reads).
    """
    ids = ids or RECHECK_IDS
    cat, cal, picks = catalog(), load("calibrate"), load("picks")
    for ch in chars(cat, only):
        kp = picks["kits"].get(ch["id"])
        if kp is None:
            continue
        cands = [c for c in pick_candidates(cat, ch) if c["id"] in ids]
        if not cands:
            continue
        prereq_sets = {tuple(c["prereq"]) for c in cands} | {()}
        bases = {pr: {"char": ch["id"], "upgrades": list(pr), "key": "base:" + "+".join(pr)}
                 for pr in prereq_sets}
        builds = [{"char": ch["id"], "upgrades": c["prereq"] + [c["id"]], "key": c["id"]}
                  for c in cands]
        measure_many(cal, list(bases.values()) + builds, PLAN_FULL, f"recheck-{ch['kit']}", workers)
        ## Interval width comes from the kit's pooled run-to-run noise, which a code fix to armor
        ## does not change, so the full picks-stage estimate is reused rather than re-estimated
        ## from these few builds.
        pooled = kp.get("pooled")
        pri = kp.get("priors") or {}
        by_id = {r["id"]: i for i, r in enumerate(kp["picks"])}
        for c, b in zip(cands, builds):
            base = bases[tuple(c["prereq"])]["summary"]
            cmp_ = compare(base, b["summary"], pooled)
            row = {**c, "compare": cmp_, "summary": b["summary"], "shrunk": shrunk(cmp_, pri),
                   "applied_ok": b["summary"]["single"]["applied"] == b["upgrades"],
                   "rechecked": code_fingerprint()}
            if c["id"] in by_id:
                kp["picks"][by_id[c["id"]]] = row
            else:
                kp["picks"].append(row)
        chains = kp.setdefault("chains", {})
        for pr in bases:
            if pr:
                chains["+".join(pr)] = compare(bases[()]["summary"], bases[pr]["summary"], pooled)
        kp["picks"].sort(key=lambda r: -_nz(r["shrunk"]["overall"]))
        save("picks", picks)
    return picks


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    stage = args[0]
    only = [a for a in args[1:] if not a.startswith("--")] or None
    workers = None
    for a in args[1:]:
        if a.startswith("--workers="):
            workers = int(a.split("=", 1)[1])
    fns = {"catalog": lambda o, w: catalog(), "calibrate": stage_calibrate,
           "baseline": stage_baseline, "picks": stage_picks, "mods": stage_mods,
           "greedy": stage_greedy, "recheck": stage_recheck}
    if stage == "all":
        for s in ("calibrate", "baseline", "picks", "mods", "greedy"):
            fns[s](only, workers)
    else:
        fns[stage](only, workers)
