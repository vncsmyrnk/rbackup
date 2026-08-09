#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/zip
use os
use str


tap:run [
  [&d='compact files and directories' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/zip-calls' > $tmpdir/zip
    chmod +x $tmpdir/zip

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/du-calls' > $tmpdir/du
    chmod +x $tmpdir/du

    var testfile = $tmpdir/testfile
    echo "test content" > $testfile

    var testdir = $tmpdir/testdir
    mkdir -p $testdir

    var target-zip = $tmpdir/out.zip

    zip:compact $target-zip [$testfile $testdir] >/dev/null

    var zip-calls = [(cat $tmpdir/zip-calls)]
    tap:assert-expected $zip-calls [
      '-q '$target-zip' '$testfile
      '-q -r '$target-zip' '$testdir
      '-T '$target-zip
    ]

    var du-calls = [(cat $tmpdir/du-calls)]
    tap:assert-expected $du-calls [
      '-shL '$testfile
      '-shL '$testdir
    ]

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='compact ignores non-existent paths' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/zip-calls' > $tmpdir/zip
    chmod +x $tmpdir/zip

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/du-calls' > $tmpdir/du
    chmod +x $tmpdir/du

    var testfile = $tmpdir/testfile
    echo "test content" > $testfile
    var non-existent = $tmpdir/does-not-exist
    var target-zip = $tmpdir/out.zip

    zip:compact $target-zip [$non-existent $testfile] >/dev/null 2>$tmpdir/stderr.log

    var zip-calls = [(cat $tmpdir/zip-calls)]
    tap:assert-expected $zip-calls [
      '-q '$target-zip' '$testfile
      '-T '$target-zip
    ]

    var stderr-output = (str:trim-space (slurp < $tmpdir/stderr.log))

    tap:assert-expected $stderr-output 'ignoring '$non-existent' as it does not exist.'


    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='compact with no valid paths fails' &f={
    var tmpdir = (os:temp-dir)
    var err = ?(zip:compact $tmpdir/out.zip [$tmpdir/nonexistent])
    var is-err = (not-eq $err $ok)
    tap:assert $is-err
    os:remove-all $tmpdir
  }]

  [&d='compact with empty paths list fails' &f={
    var tmpdir = (os:temp-dir)
    var err = ?(zip:compact $tmpdir/out.zip [])
    var is-err = (not-eq $err $ok)
    tap:assert $is-err
    os:remove-all $tmpdir
  }]

  [&d='extract unzips archive to target directory' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
echo "$@" >> '$tmpdir'/unzip-calls' > $tmpdir/unzip
    chmod +x $tmpdir/unzip

    var archive = $tmpdir/archive.zip
    var target = $tmpdir/target

    zip:extract $archive $target

    var unzip-calls = [(cat $tmpdir/unzip-calls)]
    tap:assert-expected $unzip-calls [
      $archive' -d '$target
    ]

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]
]
