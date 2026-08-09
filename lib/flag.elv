use str
use flag
use path

fn parse {|@argv|
  var rclone-remote = ""
  if (has-env RBACKUP_RCLONE_REMOTE) {
    set rclone-remote = (get-env RBACKUP_RCLONE_REMOTE)
  }

  var backup-file-prefix = "backup"
  if (has-env RBACKUP_FILE_PREFIX) {
    set backup-file-prefix = (get-env RBACKUP_FILE_PREFIX)
  }

  var keep-count = 1
  if (has-env RBACKUP_KEEP_COUNT) {
    set keep-count = (get-env RBACKUP_KEEP_COUNT)
  }

  var paths = []
  if (has-env RBACKUP_PATHS) {
    set paths = [(str:split $path:list-separator $E:RBACKUP_PATHS)]
  }

  var opts = [
    &remote=$rclone-remote &help=$false &dry-run=$false
    &keep-count=$keep-count &prefix=$backup-file-prefix
  ]

  var opts-spec = [
    [&short=r &long=remote &arg-required]
    [&short=k &long=keep &arg-required]
    [&short=p &long=prefix &arg-required]
    [&short=d &long=dry-run]
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

  if (> (count $positional) 1) {
    put $opts $positional[0] $positional[1..]
    return
  }

  var first-positional
  if (== (count $positional) 0) {
    put $opts '' $paths
    return
  }

  put $opts $positional[0] $paths
}
