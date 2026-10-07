# Descent Quest Log

Ben's roadmap-to-release tool: https://claude.ai/artifact/MXbmVuYSS692TKLEqzQn6q

- `roadmap.js` holds the phases, quests and steps. `quest_log.src.html` is the app.
  `python tools/quest_log/build.py` inlines both (plus the m5x7 font) into `quest_log.html`,
  which is what gets published to the URL in `artifact_url.txt`.
- **Step and quest IDs are Ben's saved progress.** Never rename or reuse one. Add steps by
  appending the next number in a quest (`cave-run.6`); add quests with new ids; mark a dropped
  quest `cut: true` instead of deleting it.
- Progress lives in the artifact's database, not in the page: doc `progress/steps` holds
  `{done: {<stepId>: {at, by}}}`; doc `progress/state` holds `{active, started}`.

To tick a step off from any chat: ArtifactData `get` collection `progress` doc_id `steps`, then
`update` it with `if_version` and `{"done": {"<stepId>": {"at": "<ISO time>", "by": "claude"}}}`.

To change the roadmap: edit `roadmap.js`, run `build.py`, republish `quest_log.html` with the
Artifact tool passing the URL as `url` (from a new chat, read the artifact first).
