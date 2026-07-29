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
