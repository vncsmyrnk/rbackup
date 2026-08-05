#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use ../lib/io
use os

tap:run [
  [&d='read-stdin reads non-empty lines and trims whitespace' &f={
    var lines = [(printf "  alpha  \n\n   \n  beta\t \n gamma " | io:read-stdin)]
    tap:assert-expected $lines [alpha beta gamma]
  }]

  [&d='read-stdin handles empty input' &f={
    var lines = [(print "" | io:read-stdin)]
    tap:assert-expected $lines []
  }]
]
