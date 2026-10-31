# Ido Roblox

## תוכנית המשחק והגרסה החדשה

- [תוכנית העבודה המלאה — כל שמונת המפגשים](docs/ROADMAP.md)
- [יומן גרסאות ופידבק מעידו](CHANGELOG.md)
- [איך משחקים ומה לבדוק עם עידו](docs/PLAYTEST.md)
- גרסת `v6 — Ido Feedback Pass`: טיסה חופשית בגובה, אימון מהירות, כנפיים מונפשות, 4 ביומות ו־12 בלוקים צבעוניים, שומרים מקומיים, DROP/Pick Up, אוסף בבסיס והדרכה חד־פעמית.
- קובץ `AGENTS.md` מפנה את המשך העבודה לתוכנית השמורה, כדי שלא יהיה צורך לחפש בשיחות קודמות.


## כניסה למשחק ובדיקת עדכונים

- [פתיחת Ido Playtest ב־Roblox](https://www.roblox.com/games/117297879536602/)
- [מצב הבנייה וההעלאה](https://github.com/adarcook/ido-roblox/actions/workflows/build.yml): יש להמתין להצלחה גם בשלב `build` וגם בשלב `publish`.
- לאחר עדכון, צאו מהמשחק והיכנסו מחדש. שרת קיים עשוי להמשיך עם גרסה ישנה.
- אם אין גישה בטאבלט, צריך להעניק לחשבון של עידו גישה לסביבת הניסוי ב־Roblox.
- המפתח הסודי נשמר רק בהגדרות GitHub. אין להדביק אותו בקבצים או בצ׳אט.


Migration of the existing game, not a replacement game.

The untouched backup is `original/ido-roblox-backup.rbxl` (SHA256 `94795779A55A0B684AB9C98D877455608CF6BA9CAE1B458C52E8DC21BB43C57B`). Never overwrite it. External meshes, audio, textures and animations remain references to Roblox assets; this backup cannot transfer asset ownership or grant permissions.

## Build

Pinned tools: Lune 0.11.1 and Rojo 7.7.1. Initially run `lune run scripts/extract.luau` once. It exports every embedded script without executing game code, and inventories instance classes and Animation IDs. Keep the generated `src`, `scripts-map.json`, `inventory.json`, and `default.project.json` in Git.

Run `mkdir -p build`, `rojo build default.project.json -o build/code.rbxm`, then `lune run scripts/build.luau`. The full original place remains the build base. Only Source properties are replaced. Rojo is intentionally used as a code build, not a destructive live sync of the full world. Do not connect this Folder project to a live production place using Rojo serve.

CI compiles Luau, verifies instance counts and full serialization roundtrip, and checks that all properties/references other than Source equal the original. It uploads the place and source as an artifact. These are structural checks, not gameplay tests. New models/hierarchy changes require an explicit migration to the base and mapping.

## One-time Playtest setup

1. In Roblox Studio, create and publish a **separate experience** named Ido Playtest. Record its Universe ID and starting Place ID. Publishing is restricted in code to Universe `10773779271` and Place `117297879536602`. Do not point Playtest at another place in the production universe: a separate universe also isolates DataStores.
2. Grant Ido's Roblox account Playtest access to the private experience and enable tablet/mobile devices. Review account and experience eligibility restrictions in Creator Dashboard. Test access in the tablet Roblox app.
3. Check animation, mesh, image and audio permissions for the new experience. Grant access or republish under the correct owner where necessary. Stored IDs alone do not guarantee playback.
4. Create an Open Cloud API key with `universe-places` Write permission **only for the Playtest experience**. Choose expiry and network restrictions compatible with the runner. Never paste the key in chat or Git.
5. In GitHub Settings → Environments create `playtest`. Add secret `ROBLOX_PLAYTEST_API_KEY`. Add variables `PLAYTEST_UNIVERSE_ID`, `PLAYTEST_PLACE_ID`. Add repository variable `PLAYTEST_ENABLED=true` only after confirming those IDs and permissions.
6. Push/merge to main (or run the workflow manually). Successful builds then publish to Playtest. Open the experience link on the tablet and join a new session for the new version. Existing servers may keep an earlier version.

No production deployment workflow exists. Keep PR review enabled; future production publishing requires explicit approval and separate credentials. To roll back Playtest, revert the code commit and rerun, or use Roblox version history.

Publishing docs: https://create.roblox.com/docs/cloud/guides/usage-place-publishing
API keys: https://create.roblox.com/docs/cloud/auth/api-keys
Open Cloud has limitations for EditableImage, EditableMesh, PartOperation, SurfaceAppearance and BaseWrap updates. Review inventory and use Studio when those assets change. Always visually test the preserved world, wings and carry animation in Studio and on the tablet before any production release.
