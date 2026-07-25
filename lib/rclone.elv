use os
use re

var file-count-to-keep = 1

fn backup {|paths remote|
  var date-suffix = (date +'%Y%m%d%H%M%S')
  var backup-target-path = '/tmp/backup-'$date-suffix'.zip'
  var encrypted-backup-target-path = '/tmp/backup-'$date-suffix'.zip.enc'

  if (not (has-env RBACKUP_ENCRYPT_PASSWORD)) {
    fail "encrypt password not set."
  }

  for p $paths {
    if (not (os:exists &follow-symlink=$true $p)) {
      echo 'ignoring '$p' as it does not exist.' >&2
      continue
    }
    if (os:is-dir &follow-symlink=$true $p) {
      zip -qr $backup-target-path $p
    } else {
      zip -q $backup-target-path $p
    }
  } else {
    fail "no path set."
  }
  zip -T $backup-target-path

  openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt ^
    -in $backup-target-path ^
    -out $encrypted-backup-target-path ^
    -pass env:RBACKUP_ENCRYPT_PASSWORD

  rclone copy -v $encrypted-backup-target-path ^
    $remote
}

fn fetch-files-to-garbage-collect {|remote|
  var files = [(
    rclone lsf --files-only ^
      --max-depth 1 --format "tp" $remote ^
        | re:awk &sep=';' {|_ _ 1| put $1 } ^
        | keep-if {|s| re:match "backup-[0-9]{14}.zip.enc" $s } ^
        | order &reverse=$true
  )]
  if (> (count $files) $file-count-to-keep) {
    put $files[$file-count-to-keep..]
    return
  }
  put []
}

fn purge-garbage-collected {|remote|
  var files-to-garbage-collect = (fetch-files-to-garbage-collect $remote)
  if (== (count $files-to-garbage-collect) 0) {
    fail "no files to purge."
  }
  echo 'deleting '(count $files-to-garbage-collect)' files'
  peach {|file|
    rclone deletefile $remote'/'$file
    echo 'deleted '$file
  } $files-to-garbage-collect
}
