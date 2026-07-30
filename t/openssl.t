#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/openssl
use os
use str

tap:run [
  [&d='encrypt calls openssl enc with -pass stdin and pipes password' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    var openssl-calls = $tmpdir/openssl-calls
    var openssl-stdin = $tmpdir/openssl-stdin
    echo '#!/bin/sh
echo "$@" >> '$openssl-calls'
cat >> '$openssl-stdin > $tmpdir/openssl
    chmod +x $tmpdir/openssl

    var src = $tmpdir/in.txt
    var dest = $tmpdir/out.enc
    echo "test payload" > $src

    openssl:encrypt $src $dest "my-secret-password"

    var calls = [(cat $openssl-calls)]
    tap:assert-expected $calls [
      'enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in '$src' -out '$dest' -pass stdin'
    ]

    var stdin-content = (str:trim-space (slurp < $openssl-stdin))
    tap:assert-expected $stdin-content "my-secret-password"

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='decrypt calls openssl enc -d with -pass stdin and pipes password' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    var openssl-calls = $tmpdir/openssl-calls
    var openssl-stdin = $tmpdir/openssl-stdin
    echo '#!/bin/sh
echo "$@" >> '$openssl-calls'
cat >> '$openssl-stdin > $tmpdir/openssl
    chmod +x $tmpdir/openssl

    var src = $tmpdir/out.enc
    var dest = $tmpdir/decrypted.zip

    openssl:decrypt $src $dest "my-secret-password"

    var calls = [(cat $openssl-calls)]
    tap:assert-expected $calls [
      'enc -d -aes-256-cbc -pbkdf2 -iter 100000 -salt -in '$src' -out '$dest' -pass stdin'
    ]

    var stdin-content = (str:trim-space (slurp < $openssl-stdin))
    tap:assert-expected $stdin-content "my-secret-password"

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]
]
