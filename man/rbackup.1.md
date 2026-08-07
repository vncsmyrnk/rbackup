---
title: RBACKUP
section: 1
date: 2026-08-03
header: User Commands
footer: rbackup 0.0.0
author:
  - Vinicius Mayrink
---

# NAME

rbackup - simple encrypted backup manager written in Elvish and built on top of rclone

# SYNOPSIS

**rbackup** [*OPTIONS*] **generate** [*PATH*... | **-**]
**rbackup** [*OPTIONS*] **gc**
**rbackup** [*OPTIONS*] **fetch** *INDEX*
**rbackup** **-h** | **--help**

# DESCRIPTION

**rbackup** is an Elvish script that compresses, encrypts, uploads, and restores backup archives using `rclone`, `openssl`, and `zip`.

# SUBCOMMANDS

**generate** [*PATH*... | **-**]
: Compacts specified paths into a ZIP file (or reads paths line-by-line from standard input when **-** is specified), encrypts it using `openssl` with `RBACKUP_ENCRYPT_PASSWORD`, and uploads the archive to the configured `rclone` remote location.

**gc**
: Purges garbage-collected backup archives from the `rclone` remote, keeping only the specified number of recent backups.

**fetch** *INDEX*
: Downloads the encrypted backup at *INDEX* from the `rclone` remote, decrypts it, and extracts the contents into a temporary directory.

# OPTIONS

-r, --remote *REMOTE:FOLDER/PATH*
: Specify the destination `rclone` remote and target directory. Overrides the `RBACKUP_RCLONE_REMOTE` environment variable.

-k, --keep *NUM*
: Specify the number of backup archives to retain when running the `gc` subcommand. Defaults to `1` (or `RBACKUP_KEEP_COUNT`).

-d, --dry-run
: Perform a dry run for the `gc` subcommand, listing files that would be purged without deleting them.

-h, --help
: Display usage and help information.

# ENVIRONMENT

RBACKUP_RCLONE_REMOTE
: Default `rclone` remote destination in `REMOTE:FOLDER/PATH` format.

RBACKUP_ENCRYPT_PASSWORD
: Password used for OpenSSL archive encryption and decryption. Must be set prior to running **generate** or **fetch**.

RBACKUP_PATHS
: Colon-separated (`:`) list of default file system paths to include in the backup.

RBACKUP_KEEP_COUNT
: Default number of backup archives to keep during garbage collection.

# EXAMPLES

**Create an encrypted backup of specified directories:**

```sh
export RBACKUP_ENCRYPT_PASSWORD="secret-passphrase"
rbackup --remote myremote:backups/myhost generate /home/user/documents /home/user/pictures
```

**Create an encrypted backup by streaming paths from standard input:**

```sh
export RBACKUP_ENCRYPT_PASSWORD="secret-passphrase"
find /home/user/documents -type f | rbackup --remote myremote:backups/myhost generate -
```

**Clean up old backups, retaining the 5 most recent archives:**

```sh
rbackup --remote myremote:backups/myhost --keep 5 gc
```

**Fetch and decrypt the most recent backup:**

```sh
rbackup --remote myremote:backups/myhost fetch 0
```

# SEE ALSO

`rclone(1)`, `openssl(1)`, `zip(1)`
