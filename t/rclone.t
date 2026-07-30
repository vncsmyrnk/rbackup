#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/rclone
use os
use str
use re

tap:run [
  [&d='purge-garbage-collected' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    var rclone-calls = $tmpdir/rclone-calls
    echo '#!/bin/sh
echo "$@" >> '$rclone-calls'
if [ "$1" = "lsf" ]; then
  echo "2023-01-01 10:00:00;backup-20230101100000.zip.enc"
  echo "2023-01-02 10:00:00;backup-20230102100000.zip.enc"
fi
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    rclone:purge-garbage-collected dummy-remote 1 >/dev/null

    var calls = [(cat $rclone-calls)]
    tap:assert-expected $calls [
      'lsf --files-only --max-depth 1 --format tp dummy-remote'
      'deletefile dummy-remote/backup-20230101100000.zip.enc'
    ]

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='purge-garbage-collected with keep count as two' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    var rclone-calls = $tmpdir/rclone-calls
    echo '#!/bin/sh
echo "$@" >> '$rclone-calls'
if [ "$1" = "lsf" ]; then
  echo "2023-01-01 10:00:00;backup-20230101100000.zip.enc"
  echo "2023-01-02 11:00:00;backup-20230102100000.zip.enc"

  echo "2023-01-03 12:00:00;backup-20230103100000.zip.enc"
  echo "2023-01-04 13:00:00;backup-20230104100000.zip.enc"
fi
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    rclone:purge-garbage-collected dummy-remote 2 >/dev/null

    var calls = [(cat $rclone-calls)]
    tap:assert-expected $calls[0] 'lsf --files-only --max-depth 1 --format tp dummy-remote'
    tap:assert-expected (count $calls) (num 3)
    tap:assert (or (eq $calls[1] 'deletefile dummy-remote/backup-20230101100000.zip.enc') (eq $calls[2] 'deletefile dummy-remote/backup-20230101100000.zip.enc'))
    tap:assert (or (eq $calls[1] 'deletefile dummy-remote/backup-20230102100000.zip.enc') (eq $calls[2] 'deletefile dummy-remote/backup-20230102100000.zip.enc'))

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='upload' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/rclone-calls
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    var testfile = $tmpdir/testfile.zip.enc
    echo "dummy zip enc content" > $testfile

    rclone:upload dummy-remote $testfile >/dev/null

    var rclone-calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected $rclone-calls ['copy -v '$testfile' dummy-remote']

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='fetch success' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/rclone-calls
if [ "$1" = "lsf" ]; then
  echo "2023-01-01 10:00:00;backup-20230101100000.zip.enc"
  echo "2023-01-02 10:00:00;backup-20230102100000.zip.enc"
fi
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    var target-dir = $tmpdir/target
    mkdir -p $target-dir

    var fetched = (rclone:fetch dummy-remote 1 $target-dir)

    var rclone-calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected (count $rclone-calls) (num 2)
    tap:assert-expected $rclone-calls[0] 'lsf --files-only --max-depth 1 --format tp dummy-remote'
    tap:assert-expected $rclone-calls[1] 'copy dummy-remote/backup-20230102100000.zip.enc '$target-dir
    tap:assert-expected $fetched $target-dir'/backup-20230102100000.zip.enc'

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='fetch index out of bounds fails' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
if [ "$1" = "lsf" ]; then
  echo "2023-01-01 10:00:00;backup-20230101100000.zip.enc"
fi
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    var err = ?(rclone:fetch dummy-remote 2 $tmpdir >/dev/null)
    var is-err = (not-eq $err $ok)
    tap:assert $is-err

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]
]
