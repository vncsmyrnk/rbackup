#!/usr/bin/env elvish
# vim: set ft=elvish:

use github.com/tesujimath/elvish-tap/tap
use os
use str
use re
use ../lib/openssl
use ../lib/zip

fn setup-env {|tmpdir|
  var pwd = (pwd)
  var old-path = $E:PATH
  var old-xdg = (if (has-env XDG_CONFIG_HOME) { get-env XDG_CONFIG_HOME } else { put "" })

  mkdir -p $tmpdir/elvish/lib
  os:symlink $pwd/lib $tmpdir/elvish/lib/rbackup

  set E:XDG_CONFIG_HOME = $tmpdir
  set E:PATH = $tmpdir':'$old-path

  echo '#!/bin/sh
if [ "$1" = "-g" ]; then
  echo "dummy-stty-state"
fi
' > $tmpdir/stty
  chmod +x $tmpdir/stty

  echo '#!/bin/sh
echo "$@" >> '$tmpdir'/rclone-calls

target_enc=""
dest_dir=""

for arg; do
  case "$arg" in
    *.zip.enc) target_enc="$arg" ;;
    *) if [ -d "$arg" ]; then dest_dir="$arg"; fi ;;
  esac
done

if [ -n "$target_enc" ]; then
  zip_raw="${target_enc%.enc}"
  if [ -f "$target_enc" ] && [ -f "$zip_raw" ]; then
    echo "rclone-received-verified $target_enc" >> '$tmpdir'/rclone-received
    cp "$target_enc" '$tmpdir'/uploaded.zip.enc
  elif [ -n "$dest_dir" ]; then
    fname=$(basename "$target_enc")
    tmpzip="$dest_dir/tmp.zip"
    echo "test-payload" > "$dest_dir/payload.txt"
    zip -q "$tmpzip" "$dest_dir/payload.txt"
    printf "%s\n" "$RBACKUP_ENCRYPT_PASSWORD" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in "$tmpzip" -out "$dest_dir/$fname" -pass stdin
    rm -f "$tmpzip" "$dest_dir/payload.txt"
  fi
else
  echo "2023-01-01 10:00:00;backup-20230101100000.zip.enc"
  echo "2023-01-02 10:00:00;backup-20230102100000.zip.enc"
  echo "2023-01-03 10:00:00;backup-20230103100000.zip.enc"
fi
' > $tmpdir/rclone
  chmod +x $tmpdir/rclone

  put $old-path $old-xdg
}

fn teardown-env {|tmpdir old-path old-xdg|
  set E:PATH = $old-path
  if (eq $old-xdg "") {
    unset-env XDG_CONFIG_HOME
  } else {
    set E:XDG_CONFIG_HOME = $old-xdg
  }
  os:remove-all $tmpdir
}

fn run-rbackup-expect-fail {|@args|
  var stderr-file = (os:temp-file "rbackup-stderr*")
  var err = ?(./rbackup $@args 2>$stderr-file >/dev/null)
  var stderr-text = (str:trim-space (cat $stderr-file[name]))
  os:remove $stderr-file[name]
  put $err $stderr-text
}

fn create-test-files {|files-map|
  for k [(keys $files-map)] {
    echo $files-map[$k] > $k
  }
}

fn verify-uploaded-backup {|tmpdir password expected-files-map|
  var uploaded-enc = $tmpdir/uploaded.zip.enc
  tap:assert (os:exists $uploaded-enc)

  var extract-dir = (os:temp-dir)
  var dec-zip = $extract-dir/decrypted.zip
  openssl:decrypt $uploaded-enc $dec-zip $password
  zip:extract $dec-zip $extract-dir >/dev/null

  for path [(keys $expected-files-map)] {
    var content = $expected-files-map[$path]
    var extracted-path = $extract-dir$path
    tap:assert (os:exists $extracted-path)
    var actual-content = (str:trim-space (cat $extracted-path))
    tap:assert-expected $actual-content $content
  }

  os:remove-all $extract-dir
}

tap:run [
  [&d='generate with positional args and --remote flag' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var file1 = $tmpdir/file1
    var file2 = $tmpdir/file2
    var expected-files = [&$file1="test1" &$file2="test2"]
    create-test-files $expected-files

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    ./rbackup generate --remote myremote:folder $file1 $file2 >/dev/null

    var received = [(cat $tmpdir/rclone-received)]
    tap:assert (re:match "^rclone-received-verified /tmp/backup-.*\\.zip\\.enc$" $received[0])
    verify-uploaded-backup $tmpdir "secret-pass" $expected-files

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='generate with RBACKUP_PATHS and RBACKUP_RCLONE_REMOTE env vars' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var file1 = $tmpdir/envfile1
    var file2 = $tmpdir/envfile2
    var expected-files = [&$file1="test1" &$file2="test2"]
    create-test-files $expected-files

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    set E:RBACKUP_RCLONE_REMOTE = "envremote:backup"
    set E:RBACKUP_PATHS = $file1':'$file2

    ./rbackup generate >/dev/null

    var received = [(cat $tmpdir/rclone-received)]
    tap:assert (re:match "^rclone-received-verified /tmp/backup-.*\\.zip\\.enc$" $received[0])
    verify-uploaded-backup $tmpdir "secret-pass" $expected-files

    unset-env RBACKUP_RCLONE_REMOTE
    unset-env RBACKUP_PATHS
    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='generate with paths piped from stdin (-)' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var file1 = $tmpdir/stdinfile1
    var file2 = $tmpdir/stdinfile2
    var expected-files = [&$file1="test1" &$file2="test2"]
    create-test-files $expected-files

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"

    var _ = (print $file1"\n"$file2"\n" | ./rbackup generate --remote myremote:folder - | slurp)

    var received = [(cat $tmpdir/rclone-received)]
    tap:assert (re:match "^rclone-received-verified /tmp/backup-.*\\.zip\\.enc$" $received[0])
    verify-uploaded-backup $tmpdir "secret-pass" $expected-files

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='generate with mixed positional args and stdin (-)' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var file1 = $tmpdir/pos1
    var file2 = $tmpdir/stdin1
    var file3 = $tmpdir/pos2
    var expected-files = [&$file1="test1" &$file2="test2" &$file3="test3"]
    create-test-files $expected-files

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"

    var _ = (print $file2"\n" | ./rbackup generate --remote myremote:folder $file1 - $file3 | slurp)

    var received = [(cat $tmpdir/rclone-received)]
    tap:assert (re:match "^rclone-received-verified /tmp/backup-.*\\.zip\\.enc$" $received[0])
    verify-uploaded-backup $tmpdir "secret-pass" $expected-files

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='generate fails when RBACKUP_ENCRYPT_PASSWORD is missing' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var file1 = $tmpdir/file1
    echo "test" > $file1

    unset-env RBACKUP_ENCRYPT_PASSWORD

    var err stderr = (run-rbackup-expect-fail generate --remote myremote:folder $file1)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "encrypt password not set."

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='gc with --keep flag' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err = ?(./rbackup gc --remote myremote:folder --keep 1 >/dev/null)
    tap:assert-expected $err $ok

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (> (count $calls) 1)

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='gc with RBACKUP_KEEP_COUNT env var' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_KEEP_COUNT = 1
    var err = ?(./rbackup gc --remote myremote:folder >/dev/null)
    tap:assert-expected $err $ok

    unset-env RBACKUP_KEEP_COUNT
    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='gc with no files to purge outputs message and exits 0' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_KEEP_COUNT = 5
    var stdout-file = $tmpdir/stdout
    var err = ?(./rbackup gc --remote myremote:folder >$stdout-file)
    tap:assert-expected $err $ok
    var output = (str:trim-space (cat $stdout-file))
    tap:assert-expected $output "no files to purge."

    unset-env RBACKUP_KEEP_COUNT
    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch subcommand end-to-end' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    var err = ?(./rbackup fetch --remote myremote:folder 1 >/dev/null)
    tap:assert-expected $err $ok

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch index out of bounds fails' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    var err stderr = (run-rbackup-expect-fail fetch --remote myremote:folder 10)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "index not found."

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fails when subcommand is missing' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err stderr = (run-rbackup-expect-fail --remote myremote:folder)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "a valid subcommand is necessary."

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fails when remote is missing' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err stderr = (run-rbackup-expect-fail gc)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "you need to specify the rclone remote."

    teardown-env $tmpdir $old-path $old-xdg
  }]
]
