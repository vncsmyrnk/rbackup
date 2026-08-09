use os

fn compact {|target-path paths &junk-paths=$false|
  var added = 0
  for p $paths {
    if (not (os:exists &follow-symlink=$true $p)) {
      echo 'ignoring '$p' as it does not exist.' >&2
      continue
    }

    var zip-args = [-q]
    if $junk-paths {
      set zip-args = [$@zip-args -j]
    }
    if (os:is-dir &follow-symlink=$true $p) {
      set zip-args = [$@zip-args -r]
    }

    zip $@zip-args $target-path $p
    echo (du -shL $p)
    set added = (+ $added 1)
  }
  if (== $added 0) {
    fail "no path set."
  }
  zip -T $target-path
}

fn extract {|archive-path target-dir|
  unzip $archive-path -d $target-dir
}
