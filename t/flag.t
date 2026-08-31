#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/flag
use path

fn setup-env {
  unset-env RBACKUP_FILE_PREFIX
  unset-env RBACKUP_JUNK_PATHS
  unset-env RBACKUP_KEEP_COUNT
  unset-env RBACKUP_PATHS
  unset-env RBACKUP_RCLONE_REMOTE
}

tap:run [
  [&d='parse with remote and positional args' &f={
    setup-env
    var opts sub paths = (flag:parse -r myremote generate path/to/backup)
    tap:assert-expected $opts [&remote=myremote &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths [path/to/backup]
  }]
  [&d='parse with environment RBACKUP_RCLONE_REMOTE' &f={
    setup-env
    set-env RBACKUP_RCLONE_REMOTE envremote
    var opts sub paths = (flag:parse generate path/to/backup)
    tap:assert-expected $opts [&remote=envremote &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths [path/to/backup]
    unset-env RBACKUP_RCLONE_REMOTE
  }]
  [&d='parse ignores RBACKUP_PATHS' &f={
    setup-env
    set-env RBACKUP_PATHS 'path1'$path:list-separator'path2'
    var opts sub paths = (flag:parse generate)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub "generate"
    tap:assert-expected $paths []
    unset-env RBACKUP_PATHS
  }]
  [&d='parse with environment RBACKUP_KEEP_COUNT' &f={
    setup-env
    set-env RBACKUP_KEEP_COUNT 2
    var opts sub paths = (flag:parse -r myremote generate path/to/backup)
    tap:assert-expected $opts [&remote=myremote &help=$false &dry-run=$false &keep-count=2 &prefix=backup &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths [path/to/backup]
    unset-env RBACKUP_KEEP_COUNT
  }]
  [&d='parse with --help flag' &f={
    setup-env
    var opts sub paths = (flag:parse --help generate)
    tap:assert-expected $opts [&remote='' &help=$true &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths []
  }]
  [&d='parse with -d flag' &f={
    setup-env
    var opts sub paths = (flag:parse -d gc)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$true &keep-count=1 &prefix=backup &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'gc'
    tap:assert-expected $paths []
  }]
  [&d='parse with --dry-run flag' &f={
    setup-env
    var opts sub paths = (flag:parse --dry-run gc)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$true &keep-count=1 &prefix=backup &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'gc'
    tap:assert-expected $paths []
  }]
  [&d='parse with environment RBACKUP_FILE_PREFIX' &f={
    setup-env
    set-env RBACKUP_FILE_PREFIX custom-prefix
    var opts sub paths = (flag:parse -r myremote generate path/to/backup)
    tap:assert-expected $opts [&remote=myremote &help=$false &dry-run=$false &keep-count=1 &prefix=custom-prefix &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths [path/to/backup]
    unset-env RBACKUP_FILE_PREFIX
  }]
  [&d='parse with -p flag' &f={
    setup-env
    var opts sub paths = (flag:parse -p test-prefix generate)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=test-prefix &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths []
  }]
  [&d='parse with --prefix flag' &f={
    var opts sub paths = (flag:parse --prefix test-prefix generate)
    setup-env
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=test-prefix &junk-paths=$false &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths []
  }]
  [&d='parse with -j flag' &f={
    setup-env
    var opts sub paths = (flag:parse -j generate)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$true &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths []
  }]
  [&d='parse with --junk-paths flag' &f={
    setup-env
    var opts sub paths = (flag:parse --junk-paths generate)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$true &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths []
  }]
  [&d='parse with environment RBACKUP_JUNK_PATHS' &f={
    setup-env
    set-env RBACKUP_JUNK_PATHS 'true'
    var opts sub paths = (flag:parse generate)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$true &index=0 &range='']
    tap:assert-expected $sub 'generate'
    tap:assert-expected $paths []
    unset-env RBACKUP_JUNK_PATHS
  }]
  [&d='parse with -i flag' &f={
    setup-env
    var opts sub paths = (flag:parse -i 2 fetch)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$false &index='2' &range='']
    tap:assert-expected $sub 'fetch'
    tap:assert-expected $paths []
  }]
  [&d='parse with --index flag' &f={
    setup-env
    var opts sub paths = (flag:parse --index 2 fetch)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$false &index='2' &range='']
    tap:assert-expected $sub 'fetch'
    tap:assert-expected $paths []
  }]
  [&d='parse with --range flag' &f={
    setup-env
    var opts sub paths = (flag:parse --range 0-2 fetch)
    tap:assert-expected $opts [&remote='' &help=$false &dry-run=$false &keep-count=1 &prefix=backup &junk-paths=$false &index=0 &range='0-2']
    tap:assert-expected $sub 'fetch'
    tap:assert-expected $paths []
  }]
]
