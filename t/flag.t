#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/flag
use path

tap:run [
  [&d='parse with remote and positional args' &f={
    var opts pos = (flag:parse -r myremote generate path/to/backup)
    tap:assert-expected $opts [&remote=myremote &help=$false]
    tap:assert-expected $pos [generate path/to/backup]
  }]
  [&d='parse with environment RBACKUP_RCLONE_REMOTE' &f={
    set-env RBACKUP_RCLONE_REMOTE envremote
    var opts pos = (flag:parse generate path/to/backup)
    tap:assert-expected $opts [&remote=envremote &help=$false]
    tap:assert-expected $pos [generate path/to/backup]
    unset-env RBACKUP_RCLONE_REMOTE
  }]
  [&d='parse with environment RBACKUP_PATHS fallback' &f={
    set-env RBACKUP_PATHS 'path1'$path:list-separator'path2'
    var opts pos = (flag:parse -r envremote)
    tap:assert-expected $opts [&remote=envremote &help=$false]
    tap:assert-expected $pos [path1 path2]
    unset-env RBACKUP_PATHS
  }]
  [&d='parse with --help flag' &f={
    var opts pos = (flag:parse --help generate)
    tap:assert-expected $opts [&remote='' &help=$true]
    tap:assert-expected $pos [generate]
  }]
]
