# Tummi

An iOS infant-feeding app that shows its work: every recommendation names the guideline or
trial it comes from, and every number can be replaced by the one your own paediatrician gave you.

SwiftUI + Clean Swift (VIP), SwiftData, iOS 17+. English and Russian.

## Why this and not another baby tracker

The market splits in two and neither half does the other's job:

- **Content apps** (Solid Starts and friends) explain what to introduce and how to cut it, but
  refuse to count anything — their philosophy is that the baby decides how much.
- **Tracker apps** (Baby Daybook, Huckleberry, Tinylog) count millilitres and plot WHO
  percentiles, but never say a word about what to feed or why.

Tummi sits in the gap:

1. **Amounts against guidance.** "7 mo 2 wk: today's range is 90–257 g across 2–3 meals; you
   have logged 140 g." The WHO portion ladder is interpolated across each stage, so the target
   moves with the baby instead of jumping on a birthday.
2. **A citation under every claim.** Tap it and the source opens. `Core/Evidence.swift` is the
   whole basis of the app: 18 sources, every DOI verified against Crossref. A test asserts that
   no food in the library cites a source that is not in the table.
3. **"My paediatrician said otherwise."** Introduction ages and daily amounts can be overridden
   per child, attributed to the doctor who set them, and the published range stays visible
   alongside. Hard safety limits — honey before 12 months, high-mercury fish — are *not*
   overridable, and a test pins that.
4. **Lapsed allergens.** Exposure counts are derived from logged meals, and the Today screen
   surfaces whichever allergen has gone longest without one — losing tolerance after stopping is
   the failure mode the LEAP and EAT trials actually warn about, and no other app watches for it.

## Building

```sh
xcodegen generate
xcodebuild -project Tummi.xcodeproj -scheme Tummi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Tummi.xcodeproj -scheme Tummi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`.xcodeproj` is generated and gitignored — regenerate with `xcodegen`.

### DEBUG launch arguments

| Argument | Effect |
| --- | --- |
| `-DemoSeed 1` | Seeds a 7½-month-old with 3 weeks of feeds, nappies and 8 growth points |
| `-DemoEmpty 1` | With `-DemoSeed`: creates the child but logs nothing — the real first run |
| `-DemoReset 1` | Wipes existing children first |
| `-DemoOverrides 1` | Adds a paediatrician plan (Dr Ivanova) and switches it on |
| `-OpenTab N` | Opens tab 0–4 (Today, Log, Foods, Plan, Growth) |
| `-OpenFood <id>` | Opens a food's detail screen, e.g. `-OpenFood peanut` |
| `-OpenSources 1` | Opens the full source library |
| `-OnboardingPage N` | Jumps to an onboarding page |

```sh
xcrun simctl launch <udid> com.antonpenkov.tummi -DemoSeed 1 -DemoOverrides 1 -OpenTab 3
```

### Deep links

`tummi://log/solid`, `tummi://log/bottle`, `tummi://log/breast`, `tummi://log/water`,
`tummi://foods`, `tummi://plan`, `tummi://growth`. The widget uses them so a tap lands on the
sheet that changes the figure it showed.

## Layout

```
Tummi/
  App/            TummiApp, RootView (tab bar + onboarding gate)
  Core/
    Models.swift          value-type DTOs, the interface between store and interactors
    Persistence.swift     SwiftData @Model classes (CloudKit-safe: defaults, no unique attrs)
    StorageWorker.swift   the only thing that touches SwiftData
    Evidence.swift        the source registry — nothing is asserted without a row here
    FoodTypes.swift       food, allergen, choking and nutrient types
    FoodLibrary.swift     168 foods, bilingual, with per-stage serving instructions
    Guidance.swift        age stages, portion ladder, allergen status, milestone timeline
    GrowthMath.swift      WHO LMS → z-score → percentile, with the ±3 SD tail correction
    WHOStandards.swift    generated LMS tables (do not hand-edit)
    FeedMath.swift        day totals and standing against a guidance range
    Reminders.swift       the three local notifications, rebuilt from data on every save
    Intents.swift         Siri / Shortcuts: log a bottle, log a meal, how much today
    WidgetShared.swift    the snapshot struct — the only file shared with the extension
    WidgetSync.swift      builds that snapshot from the same Guidance the Today screen uses
    DeepLink.swift        tummi:// routing
    SharedViews.swift     FlowLayout, citation chips, cards, range bars
    Theme.swift           design system, light + dark
  Scenes/         one folder per scene: Models / Interactor / Presenter / View (+ ViewStore)
TummiWidget/      WidgetKit extension (small, medium, lock-screen rectangular)
Tools/
  generate_who.py     regenerates WHOStandards.swift from the WHO xlsx tables
  build_xcstrings.py  rebuilds Localizable.xcstrings from exported strings + the Russian map
  screenshots.py      captures the App Store set on the 6.9" simulator, both locales
  make_glass_icon.py  builds AppIcon.icon — the shipping Liquid Glass icon
  make_icons.py       flat silhouette drafts, and the launch-screen mark (--launch)
AppIcon.icon/       the shipping icon: icon.json + Assets/Bowl.png + Assets/Spoon.png
IconDrafts/         flat candidates and the two contact sheets, for comparison only
docs/privacy.html   the privacy policy, ready for GitHub Pages
AppStore/           metadata.md (EN + RU listing, review notes) and screenshots/
```

Each scene follows Clean Swift: the View owns a `ViewStore: ObservableObject` that conforms to
the scene's `DisplayLogic`, wired to an Interactor and Presenter in `init`. Interactors see only
value types; Presenters own all string and colour-semantic decisions.

## Judging the first run

Demo data flatters an app. Every screen looked fine seeded with three weeks of feeds, and every
one of them was worse empty: Today opened with three zeros under three empty progress bars, which
reads as three missed targets before the parent has done anything.

`-DemoSeed 1 -DemoEmpty 1` creates the child and stops there. Capture the tabs that way before
believing any screenshot:

```sh
for t in 0 1 2 3 4; do
  xcrun simctl terminate <udid> com.antonpenkov.tummi
  xcrun simctl launch <udid> com.antonpenkov.tummi -DemoSeed 1 -DemoEmpty 1 -OpenTab $t
  sleep 3 && xcrun simctl io <udid> screenshot empty-$t.png
done
```

What that surfaced, and what now covers it: an onboarding tour page naming the five tabs, a
dismissible `FirstRunHint` explaining that citation chips are links, `EmptyStateView` carrying its
own action button instead of pointing at a corner, and a day-empty card on Today that states the
range rather than scoring the parent against it.

This is still one person's judgement. The honest test is a parent with an actual infant.

## Data provenance

Growth curves are the real WHO Child Growth Standards (2006), extracted from the published
z-score spreadsheets on who.int for weight-for-age, length-for-age and head-circumference-for-age,
months 0–24, both sexes. `GrowthMathTests` reconstructs the published ±2 and ±3 SD lines from the
stored L, M and S parameters, so a bad regeneration fails the build rather than shipping wrong
percentiles.

The 18 sources in `Evidence.swift` were checked individually: the eight journal articles resolve
through Crossref with matching title, journal and year. Publisher and CDC pages reject scripted
requests (HTTP 403) but open normally in a browser, which is where the app sends them.

## Localization

UI chrome goes through `String(localized:)` and `Localizable.xcstrings` (310 keys, English source
+ Russian, with plural variations for count strings). The catalogue is compiled into the widget
target too, because an extension resolves strings against its own bundle. Content — food names,
serving instructions, guidance copy — ships as `LocalizedText(en, ru)` data instead, because the
food library is meant to grow and a curator adding a food should not have to touch the catalogue.

To add UI copy: write the English literal, then

```sh
xcodebuild -project Tummi.xcodeproj -scheme Tummi \
  -exportLocalizations -localizationPath /tmp/tummi_loc -exportLanguage ru
python3 Tools/build_xcstrings.py "/tmp/tummi_loc/ru.xcloc/Localized Contents/ru.xliff"
```

The script prints every key with no Russian entry, so a missing translation is loud.

**Trap worth knowing:** for a string with more than one interpolation, the key
`String(localized: "\(a) and \(b)")` builds at runtime does not match the positional key
(`%1$@ and %2$@`) the exporter writes, so the lookup misses and the string silently stays English.
Multi-argument strings therefore use `String(format: String(localized: "%1$@ …"), a, b)`.

## Privacy and App Review posture

- No account, no server, no analytics, no third-party SDKs. SwiftData store on device only.
  App Privacy answers as "Data Not Collected".
- Not in the Kids Category — the audience is parents, which keeps 5.1.4/COPPA out of scope.
- Guideline 1.4.1: onboarding requires acknowledging that the app is not a doctor, does not
  diagnose, and is subordinate to the family's paediatrician; the acknowledgement is timestamped.
  Reaction logging and out-of-band growth readings both point at real care rather than reassuring.
- No WHO/AAP/ESPGHAN marks are used. Sources are cited and linked, never branded.

## The app icon

Tummi ships a layered **Liquid Glass** icon (`AppIcon.icon`), not a flat PNG. On iOS 26 a
baked PNG is passed through untouched and reads as an iOS 18 icon on an iOS 26 home screen;
the glass material, specular highlight, drop shadow and background gradient only appear if
the system is handed layers plus a fill. It then derives the light, dark and tinted 1024s
itself, and generates the legacy 60/76pt sizes, so the iOS 17 deployment target still gets a
proper icon with no `AppIcon.appiconset` in the catalogue.

```sh
python3 Tools/make_glass_icon.py --list
python3 Tools/make_glass_icon.py --install bowl-spoon
```

Two things worth knowing if you touch it:

- Layers must draw **no** highlight, bevel or shadow of their own. They are flat cream
  silhouettes on transparency; anything three-dimensional fights the system compositor.
- `automatic-gradient` needs a **four**-component colour. Three fails the build with
  `Expected four comma separated color components`, and the surrounding actool crash
  (`attempt to insert nil object`) buries the real message several lines up.

`Tools/make_icons.py` still draws flat silhouettes for quickly comparing shapes at
home-screen size, and generates the launch-screen mark (`--launch`), which is a flat image.

## Extensions and system integration

**Widget** (`TummiWidget/`) — small, medium and lock-screen rectangular. It reads a JSON
snapshot from the `group.com.antonpenkov.tummi` app group and never opens the SwiftData store,
so the store stays single-writer. `WidgetSync` builds that snapshot from the same `Guidance`
call the Today screen uses, which is why the two can't disagree about today's range. Tapping a
half of the medium widget deep-links to the sheet that changes the figure it shows.

The store URL is pinned explicitly in `Persistence.storeURL`. SwiftData relocates its default
store into the shared container the moment an app-group entitlement appears — naming the URL
means adding the widget didn't move anyone's data.

**Reminders** (`Core/Reminders.swift`) — three, all off by default: allergen upkeep (weekly, and
only when something introduced has gone quiet), a weigh-in nudge, and a note when the child
crosses into a new stage. There is deliberately no "time to feed your baby" reminder. The whole
schedule is rebuilt from data on every save, so a gap closed elsewhere cancels its own reminder.

**Siri / Shortcuts** (`Core/Intents.swift`) — log a bottle, log a meal, and ask how much has been
eaten today (the answer includes the guidance range, not just the number). Anything that needs a
judgement — which foods, how it went, whether there was a reaction — stays on a screen where the
safety copy is visible.

**iCloud sync** is written and switched off: `Persistence.iCloudSyncEnabled`, plus two entitlement
keys held in a comment in `Tummi/Tummi.entitlements`. Enabling it also means changing the App
Privacy answers and `docs/privacy.html`, which is noted in both places.

## Not done yet

- No alternate app icons.
- iCloud sync is code-ready but off; the CloudKit container does not exist yet.
- No Apple Watch app.
- Sleep tracking is a single start/stop with no analysis; nappy tracking has no trends.
- Food library covers 168 foods; Solid Starts carries 400+.
- Growth charts stop at 24 months (WHO length-for-age is published 0–2 and 2–5 separately).
- Nothing has been submitted to App Store Connect: the app record, the upload and the metadata
  paste are still to do (`AppStore/metadata.md` has everything ready to paste).
- The widget has been built and its snapshot verified, but not exercised on a real home screen.
