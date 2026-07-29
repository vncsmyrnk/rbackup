use os

fn compact {|target-path paths|
  var added = 0
  for p $paths {
    if (not (os:exists &follow-symlink=$true $p)) {
      echo 'ignoring '$p' as it does not exist.' >&2
      continue
    }
    if (os:is-dir &follow-symlink=$true $p) {
      zip -qr $target-path $p
    } else {
      zip -q $target-path $p
    }
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
