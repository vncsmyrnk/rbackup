#!/usr/bin/env elvish

use str
use path
use os

var date-suffix = (date +'%Y%m%d%H%M%S')
var backup-target-path = '/tmp/backup-'$date-suffix'.zip'
var encrypted-backup-target-path = '/tmp/backup-'$date-suffix'.enc'
var paths = [(str:split $path:list-separator $E:RBACKUP_PATHS)]

fn get-env-default {|env_name default_val|
  coalesce {
    if (has-env $env_name) {
      var val = (get-env $env_name)
        if (not-eq $val "") { put $val }
    }
  } { put $default_val }
}

for p $paths {
  if (not (os:exists &follow-symlink=$true $p)) {
    echo 'Ignoring '$p' as it does not exist.' >&2
    continue
  }
  zip -q $backup-target-path $p
}

if (not (os:exists $backup-target-path)) {
  echo 'No file was found.' >&2
  exit 1
}

zip -T $backup-target-path

# openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt \
#   -in $backup-target-path \
#   -out $encrypted-backup-target-path \
#   -pass env:RBACKUP_ENCRYPTION_PASS

var rclone-remote = 'gdrive'
if (has-env RBACKUP_RCLONE_REMOTE) {
  set rclone-remote = (get-env RBACKUP_RCLONE_REMOTE)
}

echo $rclone-remote

# rclone copy -v $backup-target-path \
#   $rclone-remote':'$rclone-folder
