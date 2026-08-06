#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/rclone
use os

tap:run [
  [&d='fetch-files' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
if [ "$1" = "lsf" ]; then
  echo "2023-01-01 10:00:00;backup-20230101100000.zip.enc"
  echo "2023-01-02 10:00:00;backup-20230102100000.zip.enc"
  echo "2023-01-01 10:00:00;other-file.zip.enc"
fi
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    var files = [(rclone:fetch-files dummy-remote)]
    tap:assert-expected $files [
      'backup-20230102100000.zip.enc'
      'backup-20230101100000.zip.enc'
    ]

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

  [&d='fetch' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/rclone-calls
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    var target-dir = $tmpdir/target
    mkdir -p $target-dir

    var fetched = (rclone:fetch dummy-remote backup-20230102100000.zip.enc $target-dir)

    var rclone-calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected $rclone-calls ['copy dummy-remote/backup-20230102100000.zip.enc '$target-dir]
    tap:assert-expected $fetched $target-dir'/backup-20230102100000.zip.enc'

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='remove' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/rclone-calls
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    rclone:remove dummy-remote backup-20230101100000.zip.enc

    var rclone-calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected $rclone-calls ['deletefile dummy-remote/backup-20230101100000.zip.enc']

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]
]

