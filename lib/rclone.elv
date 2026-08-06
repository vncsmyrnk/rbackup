use re
use path

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

fn fetch {|remote file-name target-dir|
  rclone copy $remote'/'$file-name $target-dir
  put $target-dir$path:separator$file-name
}

fn remove {|remote file-name|
  rclone deletefile $remote'/'$file-name
}
