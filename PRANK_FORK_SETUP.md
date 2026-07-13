# PrankTelegramFork setup

This repository must be based on the real Telegram-iOS source tree. The current GitHub repository was detected as empty, so first push/import Telegram-iOS, then keep this file and `codemagic.yaml` in the root.

## 1. Create Telegram API credentials

Go to:

https://my.telegram.org/apps

Create an app and save:

- `api_id`
- `api_hash`

Do not use Telegram's official name/logo for the public app. Use a custom name/icon and make it clear it is unofficial.

## 2. Codemagic variables

In Codemagic, connect the GitHub repo and create environment group `telegram_api`:

- `TELEGRAM_API_ID` = your numeric api_id
- `TELEGRAM_API_HASH` = your api_hash

For signed device builds, also create group `ios_signing`:

- `APPLE_TEAM_ID` = Apple Developer Team ID

And configure App Store Connect API integration named `codemagic` in Codemagic.

## 3. First workflow to run

Run only:

`Telegram iOS - simulator sanity build`

This does not produce an installable IPA, but it is the cheapest first check that the source tree and Telegram build system work on Codemagic.

Only after this is green, run:

`Telegram iOS - signed device IPA`

## 4. Expected cost

Telegram-iOS is huge. The first build may be slow because Bazel/cache is cold. Expect tens of minutes, not 2-3 minutes. After caches warm up, builds should get cheaper, but still not tiny.

## 5. Local visual prank feature direction

We should implement this as a local display-only layer:

- never mutate message server timestamps;
- never send fake timestamps to other users;
- apply overrides only in UI/date-separator rendering;
- add a clear local reset switch.

Initial milestone:

- hard-code a visual timestamp offset for one chat/message list;
- verify bubble time/date separators change visually;
- then add local storage and UI controls.
