#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/io
use os

tap:run [
  [&d='read-secret reads line from input and restores stty state' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    var stty-calls = $tmpdir/stty-calls
    echo '#!/bin/sh
echo "$@" >> '$stty-calls'
if [ "$1" = "-g" ]; then
  echo "speed 38400 baud; line = 0;"
fi
' > $tmpdir/stty
    chmod +x $tmpdir/stty

    var secret = (echo "my-super-secret-password" | io:read-secret "password: ")

    tap:assert-expected $secret "my-super-secret-password"

    var calls = [(cat $stty-calls)]
    tap:assert-expected $calls [
      '-g'
      '-echo'
      'speed 38400 baud; line = 0;'
    ]

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]

  [&d='read-secret handles empty input' &f={
    var tmpdir = (os:temp-dir)
    var old-path = $E:PATH
    set E:PATH = $tmpdir':'$old-path

    echo '#!/bin/sh
if [ "$1" = "-g" ]; then
  echo "dummy-stty-state"
fi
' > $tmpdir/stty
    chmod +x $tmpdir/stty

    var secret = (echo "" | io:read-secret "password: ")

    tap:assert-expected $secret ""

    set E:PATH = $old-path
    os:remove-all $tmpdir
  }]
]
