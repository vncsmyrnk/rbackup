#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use str
use path

tap:run [
  [&d='modules do not import themselves' &f={
    var lib-files = [lib/*.elv]
    var self-imports = []

    for file-path $lib-files {
      var filename = (path:base $file-path)
      var mod-name = (str:trim-suffix $filename '.elv')

      var lines = [(cat $file-path)]
      for line $lines {
        var trimmed = (str:trim-space $line)
        if (str:has-prefix $trimmed 'use ') {
          var parts = [(str:split ' ' $trimmed)]
          if (> (count $parts) 1) {
            var imported = $parts[1]
            var is-self-import = $false
            if (or (str:has-suffix $imported "/"$mod-name) (eq $imported "./"$mod-name)) {
              set is-self-import = $true
            } elif (and (eq $imported $mod-name) (not-eq $mod-name 'flag')) {
              set is-self-import = $true
            }

            if $is-self-import {
              set self-imports = [$@self-imports $file-path' imports '$imported]
            }
          }
        }
      }
    }

    tap:assert-expected $self-imports []
  }]
]
