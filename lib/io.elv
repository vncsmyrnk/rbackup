fn read-secret {|prompt|
  var old-stty = (stty -g)
  var secret = ""

  try {
    stty -echo
    print $prompt >/dev/tty
    set secret = (read-line)
  } finally {
    stty $old-stty
    echo >/dev/tty
  }

  put $secret
}
