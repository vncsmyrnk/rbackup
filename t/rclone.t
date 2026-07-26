#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/rclone
use os
use str

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
    tap:assert-expected $calls [
      'lsf --files-only --max-depth 1 --format tp dummy-remote'
      'deletefile dummy-remote/backup-20230101100000.zip.enc'
      'deletefile dummy-remote/backup-20230102100000.zip.enc'
    ]

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='backup' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/rclone-calls
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/zip-calls
echo "zip $@"' > $tmpdir/zip
    chmod +x $tmpdir/zip

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/openssl-calls
echo "openssl $@"' > $tmpdir/openssl
    chmod +x $tmpdir/openssl

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/date-calls
echo "20230101120000"' > $tmpdir/date
    chmod +x $tmpdir/date

    var testfile = $tmpdir/testfile
    echo "test" > $testfile

    var testdir = $tmpdir/testdir
    mkdir -p $testdir

    set-env RBACKUP_ENCRYPT_PASSWORD "dummy"

    rclone:backup dummy-remote [$testfile $testdir] >/dev/null

    var rclone-calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected $rclone-calls ['copy -v /tmp/backup-20230101120000.zip.enc dummy-remote']

    var zip-calls = [(cat $tmpdir/zip-calls)]
    tap:assert-expected $zip-calls ['-q /tmp/backup-20230101120000.zip '$testfile
      '-qr /tmp/backup-20230101120000.zip '$testdir
      '-T /tmp/backup-20230101120000.zip']

    var openssl-calls = [(cat $tmpdir/openssl-calls)]
    tap:assert-expected $openssl-calls [
      'enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in /tmp/backup-20230101120000.zip -out /tmp/backup-20230101120000.zip.enc -pass env:RBACKUP_ENCRYPT_PASSWORD']

    var date-calls = [(cat $tmpdir/date-calls)]
    tap:assert-expected $date-calls ['+%Y%m%d%H%M%S']

    unset-env RBACKUP_ENCRYPT_PASSWORD
    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='backup without password fails' &f={
    var err = ?(rclone:backup dummy-remote [foo])
    var is-err = (not-eq $err $ok)
    tap:assert $is-err
  }]

  [&d='backup without paths fails' &f={
    set-env RBACKUP_ENCRYPT_PASSWORD "dummy"
    var err = ?(rclone:backup dummy-remote [])
    var is-err = (not-eq $err $ok)
    tap:assert $is-err
    unset-env RBACKUP_ENCRYPT_PASSWORD
  }]
]
