#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/flag
use path

tap:run [
  [&d='parse with remote and positional args' &f={
    var opts sub paths = (flag:parse -r myremote generate path/to/backup)
    tap:assert-expected $opts [&remote=myremote &help=$false &keep-count=1]
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths [path/to/backup]
  }]
  [&d='parse with environment RBACKUP_RCLONE_REMOTE' &f={
    set-env RBACKUP_RCLONE_REMOTE envremote
    var opts sub paths = (flag:parse generate path/to/backup)
    tap:assert-expected $opts [&remote=envremote &help=$false &keep-count=1]
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths [path/to/backup]
    unset-env RBACKUP_RCLONE_REMOTE
  }]
  [&d='parse with environment RBACKUP_PATHS fallback' &f={
    set-env RBACKUP_PATHS 'path1'$path:list-separator'path2'
    var opts sub paths = (flag:parse -r envremote)
    tap:assert-expected $opts [&remote=envremote &help=$false &keep-count=1]
    tap:assert-expected $sub ''
    tap:assert-expected $paths [path1 path2]
    unset-env RBACKUP_PATHS
  }]
  [&d='parse with positional args and RBACKUP_PATHS' &f={
    set-env RBACKUP_PATHS 'path1'$path:list-separator'path2'
    var opts sub paths = (flag:parse generate)
    tap:assert-expected $opts [&remote='' &help=$false &keep-count=1]
    tap:assert-expected $sub "generate"
    tap:assert-expected $paths [path1 path2]
    unset-env RBACKUP_PATHS
  }]
  [&d='parse with environment RBACKUP_KEEP_COUNT' &f={
    set-env RBACKUP_KEEP_COUNT 2
    var opts sub paths = (flag:parse -r myremote generate path/to/backup)
    tap:assert-expected $opts [&remote=myremote &help=$false &keep-count=2]
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths [path/to/backup]
    unset-env RBACKUP_KEEP_COUNT
  }]
  [&d='parse with --help flag' &f={
    var opts sub paths = (flag:parse --help generate)
    tap:assert-expected $opts [&remote='' &help=$true &keep-count=1]
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths []
  }]
]
