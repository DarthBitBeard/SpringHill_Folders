# SpringHill Folders

Folding@home team **1068033**, based in Spring Hill, Florida.

We donate idle computer power to Folding@home, a distributed computing project for biomedical research. Your computer runs small protein folding simulations in the background and returns the results. Folding@home is free and open source, and it has produced more than 500 peer reviewed publications since 2000.

This page is the safe way to join. Download the official client, then set the team number in Web Control. No account is required to start.

## Join the team

1. Download the Folding@home v8.5 client for Windows, macOS, or Linux from the official download page: https://foldingathome.org/download
2. Run the installer. The client starts in the background when the install finishes.
3. Open Web Control at https://app.foldingathome.org and set your username and team number to **1068033**. If you are not signed in to a Folding@home Account, set the username, team, and passkey in Machine Settings. If you are signed in, set them in Account Settings so they apply to every machine on the account.
4. Click Fold.

That is it. For the full details, see the official v8.5 Client Guide: https://foldingathome.org/guides/v8-5

## Team number

Team: **1068033**
Team name: **SpringHill Folders**

A team pools the points of everyone folding under the same team number. Leave the team at 0 if you prefer no team. Points appear on the public stats leaderboards after your first work unit is returned, and stats update hourly. See the leaderboards at https://stats.foldingathome.org

## Passkey and bonus points

A passkey is not the same as a passphrase. A passphrase signs you in to your Folding@home Account. A passkey is a separate token that ties returned work units to your donor identity, and it is required for the Quick Return Bonus.

To get a passkey:

1. Request one at https://apps.foldingathome.org/passkey/create using your username and email. The passkey is emailed to you.
2. Paste it into the passkey field in Web Control. Copy and paste it, do not type it by hand, and use the same passkey on every machine you fold on.
3. Keep it private. Never post it in a forum, chat, or public repo.

To qualify for the Quick Return Bonus, you must use a passkey, successfully return at least 10 bonus eligible work units, keep an overall return rate of at least 80 percent, and return each work unit before its timeout. Bonus points are not awarded for partial returns.

Full explanation: https://foldingathome.org/faq/stats

## Control how it folds

In Web Control, Machine Settings lets you choose:

- Only When Idle, so folding pauses while you use the keyboard or mouse
- How many CPU cores Folding@home may use
- Which GPUs may fold, if any
- Whether folding may continue while on battery, on a laptop

GPU folding is usually much more efficient than CPU folding. Start with the defaults, watch temperatures and fan noise on a first run, and lower the CPU count or pause if the machine gets too hot or loud. Folding uses electricity and produces heat, so do not run it unattended on a machine with cooling problems, and pause it if you need the full machine for work or gaming.

You can also pick a preferred Cause in Account Settings, such as cancer, infectious disease, or neurological disease. The assignment server will try to match your preference, but it cannot guarantee it.

## Optional: a Folding@home Account

An account is optional. It lets you monitor and control every machine you fold on from one login, including from a phone. Register in Web Control with an email address and a passphrase, confirm the email link, and sign in on each machine. Headless machines connect with the account token from Account Settings. Rotate the token after adding machines.

Do not confuse the account passphrase with the passkey described above.

## Advanced scripts in this repo

This repo also contains `install.ps1` (Windows) and `install.sh` (Linux: Debian and Ubuntu, Fedora and RHEL derivatives, and openSUSE). They are optional and advanced. Prefer the official installer above unless you are setting up several machines you manage.

Read either script in full before running it, download it first, and run the local copy. Never run a script by piping remote content into a shell. Windows needs an Administrator PowerShell session. Linux needs sudo. Preview first with `.\install.ps1 -WhatIf` on Windows, or `./install.sh --dry-run` on Linux, then run `./install.sh --help` to see the options.

What the fixed scripts do:

- Install the client only if it is missing, and by default download nothing. Windows accepts a local installer with `-InstallerPath`, or the official latest installer alias with `-DownloadLatest`. Linux accepts a local package with `--package`, or an explicit https package URL with `--package-url`.
- Back up any existing config before changing it, and preserve an existing username, passkey, account token, and all other settings. A Linux config that already has a passkey or account token is never rewritten. A Windows config is only changed for the team number, plus a username and idle setting when those are missing.
- Write to one config location only, never to every user profile, and never add a startup registry entry or force stop a client process. The official installer already handles startup, and the service is restarted gracefully when a config changes.
- Never ask for, contain, print, or set a passkey or account token. Set those in Web Control.

If you already fold, check the backup path printed by the script and confirm your username and points identity in Web Control before folding again.

## Get help

- v8.5 Client Guide: https://foldingathome.org/guides/v8-5
- Points, stats, and passkey: https://foldingathome.org/faq/stats
- Folding@home support, forum, and Discord links are on the official support page linked from https://foldingathome.org

## About this team

SpringHill Folders was started in March 2026 and is led by Landon Beard. It welcomes anyone in Spring Hill and beyond who wants to put idle hardware to use for research. There is no fee, no signup on this repo, and no personal data collected here. Joining is just setting team 1068033 in your own Folding@home client.

---

Folding@home is a project of the Folding@home Consortium. This team page is community run and is not affiliated with, or endorsed by, Folding@home beyond the team listing itself.
