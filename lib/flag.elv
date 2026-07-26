use str
use flag
use path

fn parse {|@argv|
  var rclone-remote = ""
  if (has-env RBACKUP_RCLONE_REMOTE) {
    set rclone-remote = (get-env RBACKUP_RCLONE_REMOTE)
  }

  var keep-count = 1
  if (has-env RBACKUP_KEEP_COUNT) {
    set keep-count = (get-env RBACKUP_KEEP_COUNT)
  }

  var opts = [&remote=$rclone-remote &help=$false &keep-count=$keep-count]

  var opts-spec = [
    [&short=r &long=remote &arg-required]
    [&short=k &long=keep &arg-required]
    [&short=h &long=help]
  ]
  var parsed-opts positional = (flag:parse-getopt $argv $opts-spec)

  for o $parsed-opts {
    var value = $o[arg]
    if (eq $value '') {
      set value = $true
    }
    set opts[$o[spec][long]] = $value
  }

  if (> (count $positional) 0) {
    put $opts $positional
    return
  }

  var paths = [(str:split $path:list-separator $E:RBACKUP_PATHS)]
  put $opts $paths
}
