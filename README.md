<!-- foundation:identity -->
# NanoPet

A tamagotchi-style virtual pet that lives in the browser: feed it, play with it, put it to rest, and keep it alive stats decay over real time and persist across reloads.

- Site: https://nanopet.api.holode.xyz
- Support: support@nanopet.api.holode.xyz
<!-- /foundation:identity -->

## What this is

A tamagotchi-style virtual pet that lives in the browser: feed it, play with it, put it to rest, and keep it alive — stats decay over real time and persist across reloads.

## Who it is for

- Visitor (single-player, no account needed)

## Main features

- **Adopt a pet** — Name a new pet and pick its look, or keep the seeded default pet
- **Feed** — Raises hunger; pet reacts, logged as a care event
- **Play** — Raises happiness, costs a little energy
- **Rest** — Restores energy over a short rest
- **Watch stats decay** — Hunger/happiness/energy tick down with real elapsed time whenever the pet is viewed
- **Rescue a neglected pet** — If the pet's stats bottom out, a gentle rescue/revive path

## Core entities

- Pet
- CareEvent

## Run locally

```bash
bundle install
bin/rails db:prepare
bin/dev
```

Requires Ruby, PostgreSQL, and the usual Rails toolchain. See `bin/setup` if present.

## Demo

One seeded default pet (named Mochi, a blob-like creature) with mid-range stats and a few care events, so the app opens straight onto a living pet. Full care history visible in a small log.

## Deploy notes

Production `config.hosts` is derived from `domain` in `config/foundation.yml`. Keep that value aligned with the real host or every request will 403.
