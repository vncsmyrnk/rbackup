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

  [&d='backup' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/rclone-calls
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/openssl-calls
echo "openssl $@"' > $tmpdir/openssl
    chmod +x $tmpdir/openssl

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/date-calls
echo "20230101120000"' > $tmpdir/date
    chmod +x $tmpdir/date

    var testfile = $tmpdir/testfile.zip
    echo "dummy zip content" > $testfile

    set-env RBACKUP_ENCRYPT_PASSWORD "dummy"

    rclone:upload dummy-remote $testfile >/dev/null

    var rclone-calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected $rclone-calls ['copy -v /tmp/backup-20230101120000.zip.enc dummy-remote']

    var openssl-calls = [(cat $tmpdir/openssl-calls)]
    tap:assert-expected $openssl-calls [
      'enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in '$testfile' -out /tmp/backup-20230101120000.zip.enc -pass env:RBACKUP_ENCRYPT_PASSWORD']

    var date-calls = [(cat $tmpdir/date-calls)]
    tap:assert-expected $date-calls ['+%Y%m%d%H%M%S']

    unset-env RBACKUP_ENCRYPT_PASSWORD
    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='backup without password fails' &f={
    var err = ?(rclone:upload dummy-remote foo)
    var is-err = (not-eq $err $ok)
    tap:assert $is-err
  }]

  [&d='fetch-and-unwrap success' &f={
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

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/openssl-calls
' > $tmpdir/openssl
    chmod +x $tmpdir/openssl

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/unzip-calls
' > $tmpdir/unzip
    chmod +x $tmpdir/unzip

    set-env RBACKUP_ENCRYPT_PASSWORD "dummy"

    rclone:fetch-and-unwrap dummy-remote 1 >/dev/null

    var rclone-calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected (count $rclone-calls) (num 2)
    tap:assert-expected $rclone-calls[0] 'lsf --files-only --max-depth 1 --format tp dummy-remote'

    var rclone-copy = $rclone-calls[1]
    tap:assert (re:match 'copy dummy-remote/backup-20230102100000.zip.enc [0-9a-zA-Z/.]+' $rclone-copy)
    var extracted-tmpdir = (str:trim-prefix $rclone-copy 'copy dummy-remote/backup-20230102100000.zip.enc ')

    var openssl-calls = [(cat $tmpdir/openssl-calls)]
    tap:assert-expected $openssl-calls [
      'enc -d -aes-256-cbc -pbkdf2 -iter 100000 -salt -in '$extracted-tmpdir'/backup-20230102100000.zip.enc -out '$extracted-tmpdir'/decrypted.zip -pass env:RBACKUP_ENCRYPT_PASSWORD'
    ]

    var unzip-calls = [(cat $tmpdir/unzip-calls)]
    tap:assert-expected $unzip-calls [
      $extracted-tmpdir'/decrypted.zip -d '$extracted-tmpdir'/target'
    ]

    unset-env RBACKUP_ENCRYPT_PASSWORD
    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='fetch-and-unwrap index out of bounds fails' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
if [ "$1" = "lsf" ]; then
  echo "2023-01-01 10:00:00;backup-20230101100000.zip.enc"
fi
' > $tmpdir/rclone
    chmod +x $tmpdir/rclone

    var err = ?(rclone:fetch-and-unwrap dummy-remote 2 >/dev/null)
    var is-err = (not-eq $err $ok)
    tap:assert $is-err

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]
]
