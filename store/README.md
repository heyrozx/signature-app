# Play Store listing assets

Everything needed for the Google Play Console main store listing, in English
(`en-US`, default) and Indonesian (`id-ID`).

```
store/
├── app-icon-512.png              App icon (both languages)
├── en-US/
│   ├── listing.md                App name, short and full description
│   ├── feature-graphic.png       Feature graphic
│   └── phone-screenshots/01–07   Phone screenshots, in upload order
└── id-ID/                        Same set, in Indonesian
```

## Where each file goes

Play Console → Grow users → Store presence → Main store listing
(add Indonesian under "Manage translations").

| Asset | File | Play requirement | This file |
|---|---|---|---|
| App icon | `app-icon-512.png` | 512×512, 32-bit PNG, ≤ 1 MB | 512×512 RGBA PNG |
| Feature graphic | `<lang>/feature-graphic.png` | 1024×500, JPEG or 24-bit PNG (no alpha), ≤ 15 MB | 1024×500 RGB PNG |
| Phone screenshots | `<lang>/phone-screenshots/*.png` | 2–8 images, 16:9 or 9:16, 320–3840 px, no alpha, ≤ 8 MB each | 7 × 1080×1920 RGB PNG |
| Texts | `<lang>/listing.md` | Name ≤ 30, short ≤ 80, full ≤ 4000 characters | — |

## Screenshots

1. Two stacked phones — the canvas with a signature and the result page
2. Clean canvas with the grey placeholder
3. Undo & redo
4. Pen colors
5. Pen size
6. Auto-cropped transparent PNG
7. White background option

The app screens inside the mockups are rendered from the app's own widgets
(`lib/`) with the real fonts; the signature "Alex" is a made-up example.
Re-create the images whenever the UI changes noticeably.

Tablet screenshots are optional and not included; the app is designed for
phones.
