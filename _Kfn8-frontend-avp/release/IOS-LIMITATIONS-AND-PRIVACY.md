# Kfn8 for iPhone and iPad: limitations and privacy (draft for TestFlight notes and the App Store listing)

Status: draft (I7.S1.T2). It must match the shipped build; re-check every line against the release candidate before submission. Whether this ships as its own App Store app or as a universal purchase with the Vision Pro app is open (decision ID-1).

## What Kfn8 does with your home

- **We never upload your scan.** Room scans, the room maps used to find a room again, Spaces, Rooms and Designs stay on this iPhone or iPad. There are no accounts and no sync.
- **The camera is used only to see your room.** Video isn't recorded or sent anywhere.
- **The online catalogue:** the app talks to the Kfn8 catalogue only to list published generic furniture, download models and check whether any model's rights were withdrawn. Those requests carry no account, no device identifier and no information about your room or Designs.
- **No tracking:** there is no analytics or advertising SDK and no usage tracking. The service keeps ordinary operational logs (which endpoint, status, response time, size); it doesn't log search text or identifiers.
- **Backups:** local data is excluded from iCloud and device backups.
- **Room photos:** a photo of your room is only taken when you ask for one, after you agree to it. You choose whether to save it to Photos or share it. Kfn8 asks only to *add* photos and can't see your photo library. The app deletes its own temporary copy as soon as you close the photo.

## App Store privacy answers (to confirm against the release build)

- **Data collected:** none.
- **Tracking:** no.
- **Permissions:** Camera (`NSCameraUsageDescription`), Add to Photos only (`NSPhotoLibraryAddUsageDescription`).
- **Encryption:** standard HTTPS only (`ITSAppUsesNonExemptEncryption = false`).

## Known limitations

- **Device loss or deleting the app loses your work.** There is no Kfn8 backup or restore.
- **Devices without a depth sensor:** on iPhones and iPads without LiDAR, only scanned floors, walls, tables and seats are checked for collisions, and real furniture doesn't hide virtual items. The app says so on screen.
- **Lighting:** lamps light the virtual furniture. Whether they can also visibly light your real walls is undecided (decision ID-3); this note must say which shipped.
- **No independent accessibility audit.** VoiceOver, Dynamic Type and Reduce Motion checks are part of our own testing, not a certified audit.
- **Catalogue service availability:** single-region, single-instance, no high availability and no tested database restore.
- **Withdrawn items offline:** if a model's rights are withdrawn while you are offline, it keeps working until the app next checks online. After that it is removed, and its place in your Design is shown as unavailable rather than replaced.
- **Clearances are measured gaps, not fit guarantees.** When the scan doesn't cover a side well enough, the reading is withheld.
- **Recognising rooms:** if Kfn8 can't recognise the room, nothing is placed until you rescan into the same room; you can still review the Design's contents.
- **Previews:** a phone screen can't show furniture at true scale. Previews state the real size, and the room view shows it 1:1.
- **Scope:** indoor rooms only.

## What this document must not claim

- No certification or standards-conformance claims (accessibility, 3D formats, security).
- No performance numbers that aren't backed by a device trace (decision ID-2).
- No claim about devices that were never tested. The physical devices tested are listed in `reports/IOS-*.md`.
