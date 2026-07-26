use os
use re
use path
use str

fn backup {|remote paths|
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
    echo (du -shL $p)
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

fn fetch-files {|remote|
  put (
    rclone lsf --files-only ^
      --max-depth 1 --format "tp" $remote ^
        | re:awk &sep=';' {|_ _ 1| put $1 } ^
        | keep-if {|s| re:match "backup-[0-9]{14}.zip.enc" $s } ^
        | order &reverse=$true
  )
}

fn fetch-and-unwrap {|remote index|
  var files = [(fetch-files $remote)]
  if (< (count $files) $index) {
    fail "index not found."
  }
  var file-name = $files[(- $index 1)]
  var target-dir = (os:temp-dir)
  var backup-file-path = $target-dir$path:separator$file-name

  rclone copy $remote'/'$file-name $target-dir

  var decrypted-file-path = $target-dir$path:separator'decrypted.zip'
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -salt ^
    -in $backup-file-path ^
    -out $decrypted-file-path ^
    -pass env:RBACKUP_ENCRYPT_PASSWORD

  var target-unwrapped-dir = $target-dir$path:separator'target'
  unzip $decrypted-file-path -d $target-unwrapped-dir
}

fn fetch-files-to-garbage-collect {|remote keep-count|
  var files = [(fetch-files $remote)]
  if (> (count $files) $keep-count) {
    put $files[$keep-count..]
    return
  }
  put []
}

fn purge-garbage-collected {|remote keep-count|
  var files-to-garbage-collect = (fetch-files-to-garbage-collect $remote $keep-count)
  if (== (count $files-to-garbage-collect) 0) {
    fail "no files to purge."
  }
  echo 'deleting '(count $files-to-garbage-collect)' files'
  peach {|file|
    rclone deletefile $remote'/'$file
    echo 'deleted '$file
  } $files-to-garbage-collect
}
