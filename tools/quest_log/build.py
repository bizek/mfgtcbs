"""Build quest_log.html from quest_log.src.html + roadmap.js + the game's m5x7 font.

Run from anywhere:  python tools/quest_log/build.py
Then republish quest_log.html to the artifact URL in artifact_url.txt (see README.md).
"""
import base64
import pathlib

here = pathlib.Path(__file__).resolve().parent
root = here.parent.parent

src = (here / "quest_log.src.html").read_text(encoding="utf-8")
roadmap = (here / "roadmap.js").read_text(encoding="utf-8")
font = base64.b64encode((root / "assets" / "fonts" / "m5x7.ttf").read_bytes()).decode("ascii")
url_file = here / "artifact_url.txt"
url = url_file.read_text(encoding="utf-8").strip() if url_file.exists() else ""

out = (src.replace("/*__ROADMAP__*/", roadmap)
          .replace("__M5X7__", font)
          .replace("__ARTIFACT_URL__", url))
(here / "quest_log.html").write_text(out, encoding="utf-8")
print(f"wrote quest_log.html ({len(out) // 1024} KB), url={'set' if url else 'unset'}")
