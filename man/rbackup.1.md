---
title: RBACKUP
section: 1
date: {date}
header: User Commands
footer: name {version}
author:
  - Vinicius Mayrink
---

# NAME

rbackup - simple encrypted backup manager written in Elvish and built on top of rclone

# SYNOPSIS

**rbackup** [*OPTIONS*] **generate** [*PATH*... | **-**]
**rbackup** [*OPTIONS*] **gc**
**rbackup** [*OPTIONS*] **fetch**
**rbackup** **decrypt** [*FILE*... | **-**]
**rbackup** [*OPTIONS*] **delete**
**rbackup** [*OPTIONS*] **version**
**rbackup** **-h** | **--help**

# DESCRIPTION

**rbackup** is an Elvish script that compresses, encrypts, uploads, and restores backup archives using `rclone`, `openssl`, and `zip`.

# SUBCOMMANDS

**generate** [*PATH*... | **-**]
: Compacts specified paths into a ZIP file (or reads paths line-by-line from standard input when **-** is specified), encrypts it using `openssl` with `RBACKUP_ENCRYPT_PASSWORD`, and uploads the archive to the configured `rclone` remote location.

**gc**
: Purges garbage-collected backup archives from the `rclone` remote, keeping only the specified number of recent backups.

**fetch**
: Downloads the encrypted backup at the specified index (defaults to `0` for the most recent backup) from the `rclone` remote into a temporary directory.

**decrypt** [*FILE*... | **-**]
: Decrypts one or more encrypted backup archives and extracts their contents into temporary directories. Paths can be specified as positional arguments or read line-by-line from standard input when **-** is specified.

**delete**
: Deletes the encrypted backup at the specified index (defaults to `0` for the most recent backup) from the `rclone` remote.

**version**
: Display the version of the application.

# OPTIONS

-r, --remote *REMOTE:FOLDER/PATH*
: Specify the destination `rclone` remote and target directory. Overrides the `RBACKUP_RCLONE_REMOTE` environment variable.

-k, --keep *NUM*
: Specify the number of backup archives to retain when running the `gc` subcommand. Defaults to `1` (or `RBACKUP_KEEP_COUNT`).

-p, --prefix *PREFIX*
: Specify a custom prefix for the backup file name. Defaults to `backup` (or `RBACKUP_FILE_PREFIX`).

-i, --index *INDEX*
: Specify the index of the backup file to fetch or delete. Defaults to `0` (the most recent backup archive).

-d, --dry-run
: Perform a dry run for the `gc` subcommand, listing files that would be purged without deleting them.

-j, --junk-paths
: Do not save directory names in the backup archive. Only the file names are stored. Useful for flattening the backup structure.

-h, --help
: Display usage and help information.

# ENVIRONMENT

RBACKUP_RCLONE_REMOTE
: Default `rclone` remote destination in `REMOTE:FOLDER/PATH` format.

RBACKUP_ENCRYPT_PASSWORD
: Password used for OpenSSL archive encryption and decryption. Must be set prior to running **generate** or **decrypt**.

RBACKUP_FILE_PREFIX
: Default prefix for the backup file name.

RBACKUP_PATHS
: Colon-separated (`:`) list of default file system paths to include in the backup.

RBACKUP_KEEP_COUNT
: Default number of backup archives to keep during garbage collection.

RBACKUP_JUNK_PATHS
: Set to `1` or `true` to enable flattening of paths by default (equivalent to `-j` / `--junk-paths`).

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

**Fetch the most recent encrypted backup:**

```sh
rbackup --remote myremote:backups/myhost fetch
```

**Decrypt and extract a downloaded backup:**

```sh
rbackup decrypt /tmp/backup-20230101100000.zip.enc
```

**Fetch and decrypt multiple files at once:**

```sh
rbackup fetch --range 0-2 2>/dev/null | rbackup decrypt - 2>/dev/null
```

# SEE ALSO

`rclone(1)`, `openssl(1)`, `zip(1)`
