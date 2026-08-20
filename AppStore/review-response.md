# Reply to Guideline 2.1 — Information Needed

Paste the block below into **App Store Connect → App Review Information → Notes**, then reply
to the review message pointing at it. Attach the screen recording to the reply.

Nothing in the app needs to change: this rejection is a request for context, not a defect.
The one item that cannot be answered from a desk is the recording, which Apple requires from a
**physical device** — see "Before you reply" at the bottom.

---

## Paste-ready text

```
Thank you for reviewing Spoonlet. Answers to each point below.

1. SCREEN RECORDING
Attached. Recorded on a physical iPhone running the latest iOS, beginning with a cold
launch. Spoonlet has no account system, no purchases, no subscriptions, and no
user-generated content, so none of those flows exist to record. The only permission prompt
in the app is for local notifications, and it appears only if the user turns a reminder on
in Settings; the recording includes it.

2. DEVICES AND OPERATING SYSTEMS TESTED
- iPhone <MODEL>, iOS <VERSION> — physical device
- iPhone 17 Pro and iPhone 17 Pro Max, iOS 26.5 — Simulator
- iPad Pro 13-inch (M5), iPadOS 26.5 — Simulator, portrait and landscape
- iPhone 13 Pro Max, iOS 26.5 — Simulator
Automated test suite: 27 tests (24 unit, 3 UI) run against iOS 26.5.

3. FUNCTION AND TARGET AUDIENCE
Spoonlet is a reference and logging tool for PARENTS AND CARERS of infants aged 0–24
months. It is not intended for use by clinicians and not intended for use by children.

The problem it solves: infant-feeding apps split into two groups that do not overlap. One
group explains which foods to introduce and how to prepare them safely, but records
nothing. The other records millilitres and plots growth curves, but offers no guidance.
A parent therefore needs two apps and still cannot see whether what their baby ate today
relates to what published guidance suggests for that age.

Spoonlet does both, and cites a source for every recommendation it makes:
- Logging: breast and bottle feeds, solid meals in grams, water, nappies and sleep.
- Guidance: for the child's exact age, the published range of meals per day and amount per
  meal, shown as a range and never as a target to hit.
- A library of 168 food entries: the age each is usually introduced, whether it is one of
  the top-9 allergens, choking risk, and how to cut and serve it at 6–8 months and again
  from 9 months.
- Growth: weight, length and head circumference plotted against the WHO Child Growth
  Standards, with the percentile shown.
- Allergen exposure tracking, derived from logged meals.

Every recommendation carries a tappable citation that opens the guideline or study it comes
from. The full source list is in the app at Plan → Sources.

Spoonlet does not diagnose, does not recommend treatment, and does not replace a doctor.
Onboarding requires the user to acknowledge this before the app can be used, and the
acknowledgement is recorded with a timestamp. Where the app shows a measurement outside the
WHO ±2 SD lines, it is phrased as "worth mentioning at your next visit", never as a finding.
Users can enter their own paediatrician's amounts and introduction ages, and those replace
the published figures throughout the app.

4. SETTING UP AND ACCESSING THE FEATURES
No account, no login, no credentials, no sample files are required. Everything is available
immediately after onboarding.

To reach every feature:
a. Launch. Onboarding: tap "Get started", enter any date of birth roughly 7 months in the
   past, choose a sex, tap Continue, tap "Got it", then "I understand — start tracking".
b. Today tab: tap "Food" or "Bottle" to log a feed. Once something is logged, the screen
   shows the amount against the guidance range for that age.
c. Log tab: every entry, newest first. Tap an entry to edit it.
d. Foods tab: the food library. Tap any food, e.g. Peanut, for serving instructions,
   allergen and choking information, and the sources behind them.
e. Plan tab: guidance for the current stage and the milestone timeline. The toggle
   "Follow my paediatrician's numbers" lets any figure be replaced. The book icon in the
   top right opens the full source list.
f. Growth tab: tap "+" to add a weight or length; it is plotted against the WHO curves.
g. Settings (gear icon on Today): units, appearance, the three optional reminders, JSON
   export, and delete-all-data.

5. EXTERNAL SERVICES, TOOLS AND PLATFORMS
None. Spoonlet contains no third-party SDKs, no analytics, no advertising, no
authentication provider, no payment processing and no AI services. There is no backend: the
app has no server component and makes no network requests of its own.

All data is stored locally with SwiftData in the app's own container. The only time the
device contacts the internet on the app's behalf is when the user taps a citation, which
opens that publication's own website in Safari via openURL. Nothing about the user or their
child is transmitted.

The app declares no purpose strings because it requests no access to location, contacts,
camera, microphone, photos, health data or tracking.

6. REGIONAL DIFFERENCES
None. The app behaves identically in every region. It is localised into English and
Russian; both contain the same features and the same guidance, and the language follows the
device setting. Units can be switched between metric and imperial in Settings, which affects
display only — all values are stored metric.

7. REGULATED INDUSTRY AND THIRD-PARTY MATERIAL
Spoonlet is not a regulated medical device and is not marketed as one. It does not diagnose,
prevent, monitor or treat disease. It summarises published public-health guidance and lets a
parent keep a diary, and it defers to the family's own paediatrician by design. The
declaration in App Store Connect is answered accordingly.

On third-party material, the app reproduces none. It does the following instead:

- It cites 18 public sources by title, publisher and year, and links to them. Publications
  are named as they are published, which is how they are cited academically and how a reader
  or a doctor would find them.
- For each source it shows one or two sentences, written by us, describing what that source
  establishes. These are our own summaries, not quotations.
- The growth curves are computed from the WHO Child Growth Standards (2006) L, M and S
  parameters, which WHO publishes openly for implementation and which are attributed to WHO
  wherever they appear in the app. WHO is credited on the Growth screen and in the source
  list.
- No organisation's logo, trademark or visual identity is used anywhere in the app, its
  icon, its screenshots or its listing, and no endorsement by any organisation is claimed or
  implied. The support site carries an explicit statement to that effect.
- The keywords deliberately exclude organisation names for the same reason.

Spoonlet is free, with no in-app purchases and no subscription.

Support and privacy policy: https://antonpenkov1.github.io/spoonlet/
Source list as shown in the app: Plan tab → book icon, top right.
```

---

## Before you reply: the recording

Apple asks for a recording **from a physical device**, which is the one thing that cannot be
faked from a simulator. Record with the iPhone's own screen recorder, in one take, around
90 seconds. Suggested run:

| # | Do | Why Apple wants it |
| --- | --- | --- |
| 1 | Launch from the home screen — show the icon and the launch screen | "must begin with launching the app" |
| 2 | Walk the four onboarding pages, accept the disclaimer | Shows there is no account or paywall |
| 3 | Today → tap **Food**, pick a food, enter grams, Save | The core loop |
| 4 | Show the Today card now comparing the amount to the range | The app's actual proposition |
| 5 | Foods → tap **Peanut** → scroll to the sources → **tap one** so Safari opens | Answers point 7 visibly |
| 6 | Plan → toggle "Follow my paediatrician's numbers" → tap a figure → save one | The differentiator |
| 7 | Growth → **+** → enter a weight → show the curve | Shows the WHO chart working |
| 8 | Settings → turn on one reminder → **let the notification prompt appear** | The only permission prompt |
| 9 | Settings → scroll to "Delete all data" (do not tap) | Shows data control exists |

Fill in the model and iOS version at point 2 of the reply with whatever device you record on.

## Why this happened

Guideline 2.1 "Information Needed" is not a finding against the app. Apple asks for it
routinely on first submissions, and a Medical-category app citing WHO and AAP invites point 7
in particular. Nothing here requires a new build — the reply and the recording are enough.

One thing worth being straight about: the app had never been run on a physical device before
submission, only simulators. Apple now requires a recording from one, so that step has become
mandatory rather than advisable. Run it on the phone before recording; if anything behaves
differently there, better to find it now than in the next rejection.

## One to watch later

WHO publications are released under CC BY-NC-SA 3.0 IGO — **non-commercial**. Spoonlet is free
with no purchases, so today this is not an issue. If a paid tier is ever added, the use of WHO
material needs a second look, because the non-commercial clause stops being automatically
satisfied. The growth standards themselves are factual reference data published for
implementation, which is a different and weaker claim to copyright, but the question is worth
asking properly before charging money rather than after.
