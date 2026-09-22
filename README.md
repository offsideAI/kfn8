# Kfn8 monorepo

The repository root owns the only `.git` directory. Work targets the parent repository's `main` branch; no Git operation is permitted without the founder's explicit approval. Do not initialise nested repositories.

## Active MVP1 work

- `_Kfn8-frontend-avp/`: visionOS 27 planning, roadmap, readiness tools, reports and the AVP client source (`_Kfn8-frontend-avp-src/`, currently the nonshipping M0 probe).
- `_Kfn8-frontend-avp/_Kfn8-backend-fastapi/`: current empty backend directory; backend implementation has not started. This is a component of this monorepo, not a separate repository. No directory moves were made during the repository review.
- `Kfn8-main-ios/`: existing legacy iOS project, not an MVP1 iOS target.
- `assets/`, `assets-usdz/`, `screenshots/`, `screenshots_1_2_0/`: existing source/reference material; do not treat it as an approved MVP1 asset library.

See [technical plan](_Kfn8-frontend-avp/TECHNICAL-PLAN.md) and [status roadmap](_Kfn8-frontend-avp/ROADMAP.md). The shared root `.gitignore` covers Swift/Xcode and Python generated output, local environments and signing credentials. It intentionally does not blanket-ignore models, textures, screenshots, videos, lockfiles, shared schemes or test reports.

Run available tooling tests from this root:

```sh
python3 -m unittest discover -s _Kfn8-frontend-avp/tests -v
```

M0 device tests are not complete. The client source lives in `_Kfn8-frontend-avp/_Kfn8-frontend-avp-src/` (renamed from the misspelled empty directory on 2026-09-22); see its README for build, test and the founder device protocol.

## Historical app notes

The palette and links below describe the legacy app, not MVP1's Showroom palette or approved asset licences.

----

## Logo

Augmented Reality by Dot9 from the Noun Project
https://thenounproject.com/search/?q=Augmented+Reality&i=3157941

## AppIcon Palette color
---------------------

#3033A1 - R48 G51 B161
Floating Point sRGB)- 
R - 0.188
G - 0.200
B - 0.631

App Icon color - #1b3132

## Links
https://developer.apple.com/augmented-reality/tools/

https://youtu.be/xHXIwlqhQwY

## Sketchfab Assets
-------------------

https://sketchfab.com/3d-models/character-for-university-game-project-5751d328d0294242b882219d598e4c6b

https://sketchfab.com/3d-models/air-express-fd4b1c6cbbac4e9dba4e25a5a0b3dc5c

https://sketchfab.com/3d-models/chararacter-bike-girl-172af14b43824a99a7c83f37a3c82a15

https://sketchfab.com/3d-models/a-questing-mouse-75d8dbea0fb842bfbfc00bc8cee0ed17

https://sketchfab.com/3d-models/home-sweet-home-fantasy-house-460cede2a604440aa8eec553a3066325

https://sketchfab.com/3d-models/sad-toaster-9b158486dfa1490eb9157966321283a0
