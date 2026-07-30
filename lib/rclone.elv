use os
use re
use path
use str

fn upload {|remote file-path|
  rclone copy -v $file-path $remote
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

fn fetch {|remote index target-dir|
  var files = [(fetch-files $remote)]
  if (< (count $files) $index) {
    fail "index not found."
  }
  var file-name = $files[(- $index 1)]
  var backup-file-path = $target-dir$path:separator$file-name

  rclone copy $remote'/'$file-name $target-dir
  put $backup-file-path
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

