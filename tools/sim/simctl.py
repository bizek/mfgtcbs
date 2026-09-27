"""simctl — fan balance-sim scenarios out across headless Godot workers.

Core layer only: run a list of scenario dicts, get a list of result dicts back. The experiment
stages (rotation calibration, pick values, mod loadouts, build optimizer) live in sim_stages.py
and call run().

Results are cached on disk keyed by (scenario, game-code fingerprint). The fingerprint hashes
every .gd under scripts/ data/ tools/sim/ plus data/balance_overrides.json and anim_overrides.json,
so any change to game code or tuning invalidates exactly the cache it should, and re-running a
stage after an unrelated edit to the REPORT costs nothing.

Usage from Python:
    from simctl import run
    results = run([{"id": "x", "character": "The Drifter", "arena": "single"}])
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(os.environ.get("GODOT_BIN", r"E:\Godot\Godot_v4.6.1-stable_win64.exe"))
OUT = ROOT / "tools" / "sim" / "out"
CACHE = OUT / "cache"
JOBS = OUT / "jobs"
LOGS = OUT / "logs"

## Worker count. Each headless worker is ~300 MB; the default leaves room for the editor.
DEFAULT_WORKERS = int(os.environ.get("SIM_WORKERS", "12"))
## Scenarios per worker process. A process pays ~2 s of engine boot once, then ~0.8 s of arena
## load per scenario, so batching matters; too large a batch just makes the tail uneven.
DEFAULT_CHUNK = 24
WORKER_TIMEOUT_S = 1800

for d in (OUT, CACHE, JOBS, LOGS):
    d.mkdir(parents=True, exist_ok=True)
gi = OUT / ".gitignore"
if not gi.exists():
    gi.write_text("*\n", encoding="utf-8")


def code_fingerprint() -> str:
    h = hashlib.sha1()
    files: list[Path] = []
    for sub in ("scripts", "data", "tools/sim"):
        files += sorted((ROOT / sub).rglob("*.gd"))
    for extra in ("data/balance_overrides.json", "data/anim_overrides.json", "project.godot"):
        p = ROOT / extra
        if p.exists():
            files.append(p)
    for p in files:
        h.update(str(p.relative_to(ROOT)).encode())
        h.update(p.read_bytes())
    return h.hexdigest()[:16]


def _key(sc: dict, fp: str) -> str:
    body = {k: v for k, v in sc.items() if k != "id"}
    return hashlib.sha1((fp + json.dumps(body, sort_keys=True)).encode()).hexdigest()


def _cache_path(key: str) -> Path:
    return CACHE / key[:2] / (key + ".json")


## ── Runaway workers ───────────────────────────────────────────────────────────
## A scenario can hang the engine rather than finish: on 2026-09-27 a crit build with Static
## Discharge set off an unbounded proc chain (on-crit AoE → crit → on-crit AoE …) that overflowed
## the GDScript stack every frame, wrote a 10.6 GB log, and stalled the sweep for the full 30-minute
## worker timeout. That is a GAME finding, not a harness failure, so it is recorded as one:
##   1. a worker whose log passes LOG_RUNAWAY_BYTES, or whose runtime passes WORKER_TIMEOUT_S, is
##      killed at once;
##   2. the scenarios it already finished are kept;
##   3. the rest are re-run ONE AT A TIME with a short timeout, so the scenario at fault is
##      pinned exactly and every innocent one still gets measured;
##   4. the one at fault comes back as {"crashed": True, "error": <signature>} — cached like any
##      other result, so a re-run does not hang on it again.
LOG_RUNAWAY_BYTES = 32 * 1024 * 1024
SINGLE_TIMEOUT_S = 300


def _error_signature(log: Path) -> str:
    """The distinct SCRIPT ERROR lines and the innermost frames, from the head of the log."""
    try:
        with open(log, "rb") as fh:
            head = fh.read(2_000_000).decode("utf-8", "replace")
    except OSError:
        return "no log"
    ## Frames are read only from the backtrace directly under the first SCRIPT ERROR — headless
    ## workers also print harmless "Not supported by this display server" traces (keyboard glyph
    ## lookups at HUD setup), and those must not be mistaken for the crash.
    errs, frames = [], []
    in_trace = False
    for line in head.splitlines():
        t = line.strip()
        if t.startswith("SCRIPT ERROR"):
            if t not in errs:
                errs.append(t)
            in_trace = len(errs) == 1 and not frames
            continue
        if t.startswith("ERROR:"):
            in_trace = False
            continue
        if in_trace and t.startswith("[") and "(res://" in t and len(frames) < 8:
            frame = t.split("] ", 1)[-1]
            if frame not in frames:
                frames.append(frame)
    return (" | ".join(errs[:3]) or "no script error captured") + \
        (" :: " + " <- ".join(frames) if frames else "")


def _read_results(out: Path) -> list[dict]:
    res = []
    if out.exists():
        for line in out.read_text(encoding="utf-8").splitlines():
            if line.strip():
                res.append(json.loads(line))
    return res


def _run_chunk(chunk: list[dict], tag: str, timeout_s: float = WORKER_TIMEOUT_S) -> list[dict]:
    job = JOBS / f"{tag}.json"
    out = JOBS / f"{tag}.jsonl"
    log = LOGS / f"{tag}.log"
    job.write_text(json.dumps({"scenarios": chunk}), encoding="utf-8")
    cmd = [str(GODOT), "--headless", "--path", str(ROOT), "--fixed-fps", "60",
           "--script", "res://tools/sim/sim_runner.gd", "--",
           "--sim", f"--job={job}", f"--out={out}"]
    runaway = None
    t0 = time.time()
    with open(log, "w", encoding="utf-8", errors="replace") as lf:
        proc = subprocess.Popen(cmd, stdout=lf, stderr=subprocess.STDOUT)
        while proc.poll() is None:
            time.sleep(1.0)
            size = log.stat().st_size if log.exists() else 0
            if size > LOG_RUNAWAY_BYTES:
                runaway = f"log passed {size // (1024 * 1024)} MB"
            elif time.time() - t0 > timeout_s:
                runaway = f"ran past {int(timeout_s)} s"
            if runaway:
                proc.kill()
                proc.wait()
                break
    results = _read_results(out)
    fatal = [r for r in results if "fatal" in r]
    if fatal:
        raise RuntimeError(f"worker {tag} failed: {fatal[0]['fatal']}")
    if runaway is None and proc.returncode == 0 and len(results) == len(chunk):
        job.unlink(missing_ok=True)
        out.unlink(missing_ok=True)
        log.unlink(missing_ok=True)   # clean runs leave no log; only failures are kept to read
        return results

    # Something went wrong past the scenarios already written: isolate it.
    sig = _error_signature(log)
    try:  # keep a readable head of the log, drop the runaway body
        if log.stat().st_size > 4_000_000:
            with open(log, "rb") as fh:
                head = fh.read(4_000_000)
            log.write_bytes(head + b"\n[truncated by simctl: runaway worker]\n")
    except OSError:
        pass
    rest = chunk[len(results):]
    if len(chunk) == 1:
        print(f"[simctl] scenario crashed ({runaway or 'exit %s' % proc.returncode}): "
              f"{chunk[0].get('id')} — {sig[:200]}", flush=True)
        return [{"id": chunk[0].get("id"), "crashed": True, "error": sig,
                 "cause": runaway or f"exit {proc.returncode}"}]
    for i, sc in enumerate(rest):
        results += _run_chunk([sc], f"{tag}_iso{i}", SINGLE_TIMEOUT_S)
    job.unlink(missing_ok=True)
    out.unlink(missing_ok=True)
    return results


def run(scenarios: list[dict], workers: int = DEFAULT_WORKERS, chunk: int = DEFAULT_CHUNK,
        label: str = "run", verbose: bool = True) -> list[dict]:
    """Run scenarios (cached). Returns results in the same order as the input."""
    fp = code_fingerprint()
    keys = [_key(sc, fp) for sc in scenarios]
    results: list[dict | None] = [None] * len(scenarios)
    todo: list[int] = []
    for i, k in enumerate(keys):
        p = _cache_path(k)
        if p.exists():
            r = json.loads(p.read_text(encoding="utf-8"))
            r["id"] = scenarios[i].get("id", r.get("id"))
            results[i] = r
        else:
            todo.append(i)
    if verbose:
        print(f"[{label}] {len(scenarios)} scenarios, {len(scenarios) - len(todo)} cached, "
              f"{len(todo)} to run on {workers} workers (code {fp})", flush=True)
    if todo:
        ## Interleave so each chunk mixes characters/arenas — keeps chunk runtimes even.
        ## Enough chunks to keep every worker busy: never fewer than `workers` (when there are
        ## that many scenarios), never more than `chunk` scenarios in one process.
        n_chunks = max(min(workers, len(todo)), (len(todo) + chunk - 1) // chunk)
        chunks = [todo[i::n_chunks] for i in range(n_chunks)]
        t0 = time.time()
        done = 0

        def work(ci: int) -> tuple[list[int], list[dict]]:
            idxs = chunks[ci]
            tag = f"{label}_{int(t0)}_{ci}"
            return idxs, _run_chunk([scenarios[i] for i in idxs], tag)

        with ThreadPoolExecutor(max_workers=workers) as ex:
            for idxs, res in ex.map(work, range(len(chunks))):
                for i, r in zip(idxs, res):
                    p = _cache_path(keys[i])
                    p.parent.mkdir(parents=True, exist_ok=True)
                    r = dict(r)
                    r.pop("hit_log", None) if not scenarios[i].get("hit_log") else None
                    p.write_text(json.dumps(r), encoding="utf-8")
                    results[i] = r
                done += len(idxs)
                if verbose:
                    el = time.time() - t0
                    print(f"[{label}] {done}/{len(todo)} in {el:.0f}s "
                          f"(eta {el / done * (len(todo) - done):.0f}s)", flush=True)
    return results  # type: ignore[return-value]


if __name__ == "__main__":
    ## Smoke: python tools/sim/simctl.py job.json  → prints one line per result.
    scs = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["scenarios"]
    for r in run(scs, label="smoke"):
        print(json.dumps({k: r.get(k) for k in ("id", "dps", "kills", "seconds", "survived",
                                                 "warnings")}))
