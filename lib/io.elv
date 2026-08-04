use str

fn read-secret {|prompt|
  var old-stty = (stty -g)
  var secret = ""

  try {
    stty -echo
    print $prompt >&2
    set secret = (read-line)
  } finally {
    stty $old-stty
    echo >&2
  }

  put $secret
}

fn read-stdin {
  from-lines | each {|p|
    var trimmed = (str:trim-space $p)
      if (not-eq $trimmed "") {
        put $trimmed
      }
  }
}
