# Kfn8 MVP1 — limitations and privacy (draft for TestFlight notes and the App Store listing)

Status: draft. It must match the shipped build; re-check every line against the release candidate before submission.

## What Kfn8 does with your home

- **We never upload your scan.** Room scans, room geometry, Spaces, Rooms and Designs stay on this Apple Vision Pro. There are no accounts and no sync.
- The app talks to the Kfn8 catalogue only to list published generic furniture, download models and check whether any model's rights were withdrawn. Those requests carry no account, no device identifier and no information about your room or Designs.
- There is no analytics or advertising SDK and no usage tracking. The service keeps ordinary operational logs (which endpoint, status, response time, size); it does not log search text or identifiers.
- Local data is excluded from iCloud and device backups.
- A still image of your room is only ever created when you ask for one, after you agree to it, and only saved or shared by you. (Still export ships only if the M0 export check succeeds; see below.)

## Known limitations

- **Device loss or deleting the app loses your work.** There is no Kfn8 backup or restore in MVP1.
- **Apple Vision Pro (M5) is untested.** Acceptance testing happens on the M2 model only; performance on M5 is not claimed.
- **No independent accessibility audit.** VoiceOver reachability, Dynamic Type and reduced-motion checks are part of our own demos, not a certified audit.
- **Catalogue service availability:** single-region, single-instance, no high availability and no tested database restore.
- **Withdrawn items offline:** if a model's rights are withdrawn while you are offline, it keeps working until the app next checks online. After that it is removed and its place in your Design is shown as unavailable, not replaced.
- **Clearances are measured gaps, not fit guarantees.** When the scan doesn't cover a side well enough the reading is withheld.
- **If Kfn8 can't recognise the room**, spatial content is hidden until you rescan into the same room; you can still review the Design's contents.
- Indoor rooms only. No outdoor spaces, no full immersion, no other devices.

## What this document must not claim

No certification or standards-conformance claims (accessibility, 3D formats, security). No "we can't infer anything about your room" (a future synced Design would reveal arrangement). No performance numbers that are not backed by an M2 trace.
