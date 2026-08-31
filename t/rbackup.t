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

  unset-env RBACKUP_ENCRYPT_PASSWORD
  unset-env RBACKUP_FILE_PREFIX
  unset-env RBACKUP_JUNK_PATHS
  unset-env RBACKUP_KEEP_COUNT
  unset-env RBACKUP_PATHS
  unset-env RBACKUP_RCLONE_REMOTE

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
    tmpzip="$dest_dir/tmp.$$.zip"
    payload="$dest_dir/payload.$$.txt"
    echo "test-payload" > "$payload"
    zip -q "$tmpzip" "$payload"
    printf "%s\n" "$RBACKUP_ENCRYPT_PASSWORD" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in "$tmpzip" -out "$dest_dir/$fname" -pass stdin
    rm -f "$tmpzip" "$payload"
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

fn create-encrypted-archive {|base name content password|
  var payload = $base/$name.txt
  var archive = $base/$name.zip
  var encrypted = $base/$name.zip.enc
  echo $content > $payload
  zip:compact $archive [$payload] >/dev/null 2>&1
  openssl:encrypt $archive $encrypted $password
  put $encrypted $payload
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
    ./rbackup generate --remote myremote:folder $file1 $file2 >/dev/null 2>&1

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

    ./rbackup generate >/dev/null 2>&1

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

    var err = ?(./rbackup gc --remote myremote:folder --keep 1 >/dev/null 2>&1)
    tap:assert-expected $err $ok

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 3)

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='gc with RBACKUP_KEEP_COUNT env var' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_KEEP_COUNT = 1
    var err = ?(./rbackup gc --remote myremote:folder >/dev/null 2>&1)
    tap:assert-expected $err $ok

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 3)

    unset-env RBACKUP_KEEP_COUNT
    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='gc with no files to purge outputs message and exits 0' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_KEEP_COUNT = 5
    var stdout-file = $tmpdir/stdout
    var stderr-file = $tmpdir/stderr
    var err = ?(./rbackup gc --remote myremote:folder >$stdout-file 2>$stderr-file)
    tap:assert-expected $err $ok
    tap:assert-expected (str:trim-space (cat $stderr-file)) "no files to purge."
    tap:assert-expected (cat $stdout-file | slurp) ""

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (== (count $calls) (num 1))

    unset-env RBACKUP_KEEP_COUNT
    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch subcommand end-to-end' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var stdout-file = $tmpdir/stdout
    var err = ?(./rbackup fetch --remote myremote:folder -i 0 >$stdout-file 2>/dev/null)
    tap:assert-expected $err $ok

    var fetched-path = (str:trim-space (cat $stdout-file))
    tap:assert (re:match '\.zip\.enc$' $fetched-path)
    tap:assert (os:is-regular $fetched-path)

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 2)
    for c $calls {
      tap:assert (not (re:match ".*delete.*" $c))
    }

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch defaults to index 0 when --index flag is omitted' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    var err = ?(./rbackup fetch --remote myremote:folder >/dev/null 2>&1)
    tap:assert-expected $err $ok

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 2)
    for c $calls {
      tap:assert (not (re:match ".*delete.*" $c))
    }

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch index out of bounds fails' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    var err stderr = (run-rbackup-expect-fail fetch --remote myremote:folder -i 10)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "index not found."

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 1)
    for c $calls {
      tap:assert (not (re:match ".*delete.*" $c))
    }

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch with --range fetches multiple files' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var stdout-file = $tmpdir/stdout
    var err = ?(./rbackup fetch --remote myremote:folder --range 0-2 >$stdout-file 2>/dev/null)
    tap:assert-expected $err $ok

    var fetched = [(cat $stdout-file)]
    tap:assert-expected (count $fetched) (num 2)
    for f $fetched {
      tap:assert (re:match '\.zip\.enc$' $f)
      tap:assert (os:is-regular $f)
    }

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected (count $calls) (num 3)
    var joined-calls = (str:join "\n" $calls)
    tap:assert (re:match '(?m)copy .*backup-20230103100000.zip.enc' $joined-calls)
    tap:assert (re:match '(?m)copy .*backup-20230102100000.zip.enc' $joined-calls)

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch with --range 0-$ fetches all files' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var stdout-file = $tmpdir/stdout
    var err = ?(./rbackup fetch --remote myremote:folder --range '0-$' >$stdout-file 2>/dev/null)
    tap:assert-expected $err $ok

    var fetched = [(cat $stdout-file)]
    tap:assert-expected (count $fetched) (num 3)
    for f $fetched {
      tap:assert (os:is-regular $f)
    }

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected (count $calls) (num 4)

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch with invalid range format fails' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err stderr = (run-rbackup-expect-fail fetch --remote myremote:folder --range abc)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "invalid range format."

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected (count $calls) (num 1)

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fetch with out of bounds range fails' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err stderr = (run-rbackup-expect-fail fetch --remote myremote:folder --range 5-9)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "invalid range value."

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected (count $calls) (num 1)

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='decrypt subcommand extracts one encrypted archive without a remote' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var payload = $tmpdir/payload.txt
    var archive = $tmpdir/archive.zip
    var encrypted = $tmpdir/archive.zip.enc
    echo "test-payload" > $payload
    zip:compact $archive [$payload] >/dev/null 2>&1
    openssl:encrypt $archive $encrypted "secret-pass"

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    unset-env RBACKUP_RCLONE_REMOTE
    var stdout-file = $tmpdir/stdout
    var err = ?(./rbackup decrypt $encrypted >$stdout-file 2>/dev/null)
    tap:assert-expected $err $ok

    var target-dir = (str:trim-space (slurp < $stdout-file))
    var extracted-payload = $target-dir$payload
    tap:assert (os:is-regular $extracted-payload)
    tap:assert-expected (str:trim-space (cat $extracted-payload)) "test-payload"
    tap:assert (not (os:is-regular $tmpdir/rclone-calls))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='decrypt fails when no path is specified' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    unset-env RBACKUP_RCLONE_REMOTE
    set E:RBACKUP_PATHS = "fallback.zip.enc"
    var err stderr = (run-rbackup-expect-fail decrypt)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "you need to specify at least one path."

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='decrypt extracts multiple archives at once' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var enc1 payload1 = (create-encrypted-archive $tmpdir first payload-one secret-pass)
    var enc2 payload2 = (create-encrypted-archive $tmpdir second payload-two secret-pass)

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    unset-env RBACKUP_RCLONE_REMOTE
    var stdout-file = $tmpdir/stdout
    var err = ?(./rbackup decrypt $enc1 $enc2 >$stdout-file 2>/dev/null)
    tap:assert-expected $err $ok

    var dirs = [(cat $stdout-file)]
    tap:assert-expected (count $dirs) (num 2)
    var found1 = $false
    var found2 = $false
    for d $dirs {
      if (os:is-regular $d$payload1) { set found1 = $true }
      if (os:is-regular $d$payload2) { set found2 = $true }
    }
    tap:assert $found1
    tap:assert $found2
    tap:assert (not (os:is-regular $tmpdir/rclone-calls))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='decrypt reads paths from stdin (-)' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var enc1 payload1 = (create-encrypted-archive $tmpdir first payload-one secret-pass)
    var enc2 payload2 = (create-encrypted-archive $tmpdir second payload-two secret-pass)

    set E:RBACKUP_ENCRYPT_PASSWORD = "secret-pass"
    unset-env RBACKUP_RCLONE_REMOTE
    var stdout-file = $tmpdir/stdout
    var err = ?(print $enc1"\n"$enc2"\n" | ./rbackup decrypt - >$stdout-file 2>/dev/null)
    tap:assert-expected $err $ok

    var dirs = [(cat $stdout-file)]
    tap:assert-expected (count $dirs) (num 2)
    var found1 = $false
    var found2 = $false
    for d $dirs {
      if (os:is-regular $d$payload1) { set found1 = $true }
      if (os:is-regular $d$payload2) { set found2 = $true }
    }
    tap:assert $found1
    tap:assert $found2
    tap:assert (not (os:is-regular $tmpdir/rclone-calls))

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

  [&d='gc with --dry-run flag' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var stdout-file = $tmpdir/stdout
    var stderr-file = $tmpdir/stderr
    var err = ?(./rbackup gc --remote myremote:folder --keep 1 --dry-run >$stdout-file 2>$stderr-file)
    tap:assert-expected $err $ok
    var stderr-output = [(cat $stderr-file)]
    tap:assert-expected $stderr-output[0] 'deleting 2 files'
    tap:assert-expected $stderr-output[1] 'this is a dry-run, listed files were not actually removed.'

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 1)
    for c $calls {
      tap:assert (not (re:match ".*delete.*" $c))
    }

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='fails when remote is missing' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err stderr = (run-rbackup-expect-fail gc)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "you need to specify the rclone remote."
    tap:assert (not (os:is-regular $tmpdir/rclone-calls))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='version outputs RBACKUP_VERSION and RBACKUP_GIT_SHA' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    set E:RBACKUP_VERSION = "1.2.3"
    set E:RBACKUP_GIT_SHA = "abc1234"
    var stdout-file = $tmpdir/stdout
    var err = ?(./rbackup version --remote myremote:folder >$stdout-file)
    tap:assert-expected $err $ok
    var output = (str:trim-space (cat $stdout-file))
    tap:assert-expected $output "1.2.3-abc1234"
    tap:assert (not (os:is-regular $tmpdir/rclone-calls))

    unset-env RBACKUP_VERSION
    unset-env RBACKUP_GIT_SHA
    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='delete subcommand end-to-end' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err = ?(./rbackup delete --remote myremote:folder -i 0 >/dev/null 2>&1)
    tap:assert-expected $err $ok

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 2)
    tap:assert (or (re:match ".*backup-20230103100000.zip.enc.*" $calls[0]) ^
      (re:match ".*backup-20230103100000.zip.enc.*" $calls[1]))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='delete defaults to index 0 when --index flag is omitted' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err = ?(./rbackup delete --remote myremote:folder >/dev/null 2>&1)
    tap:assert-expected $err $ok

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 2)
    tap:assert (or (re:match ".*backup-20230103100000.zip.enc.*" $calls[0]) ^
     (re:match ".*backup-20230103100000.zip.enc.*" $calls[1]))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='delete with explicit non-zero index' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err = ?(./rbackup delete --remote myremote:folder -i 1 >/dev/null 2>&1)
    tap:assert-expected $err $ok

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (<= (count $calls) 2)
    tap:assert (or (re:match ".*backup-20230102100000.zip.enc.*" $calls[0]) ^
      (re:match ".*backup-20230102100000.zip.enc.*" $calls[1]))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='delete index out of bounds fails' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err stderr = (run-rbackup-expect-fail delete --remote myremote:folder -i 10)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "index not found."

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert (== (count $calls) 1)
    tap:assert (not (re:match ".*delete.*" $calls[0]))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='delete with --range deletes multiple files' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err = ?(./rbackup delete --remote myremote:folder --range 0-2 >/dev/null 2>&1)
    tap:assert-expected $err $ok

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected (count $calls) (num 3)
    var joined-calls = (str:join "\n" $calls)
    tap:assert (re:match '(?m)deletefile .*backup-20230103100000.zip.enc' $joined-calls)
    tap:assert (re:match '(?m)deletefile .*backup-20230102100000.zip.enc' $joined-calls)
    tap:assert (not (re:match '(?m)deletefile .*backup-20230101100000.zip.enc' $joined-calls))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='delete with out of bounds range fails' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err stderr = (run-rbackup-expect-fail delete --remote myremote:folder --range 5-9)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "invalid range value."

    var calls = [(cat $tmpdir/rclone-calls)]
    tap:assert-expected (count $calls) (num 1)
    tap:assert (not (re:match ".*deletefile.*" $calls[0]))

    teardown-env $tmpdir $old-path $old-xdg
  }]

  [&d='delete fails when remote is missing' &f={
    var tmpdir = (os:temp-dir)
    var old-path old-xdg = (setup-env $tmpdir)

    var err stderr = (run-rbackup-expect-fail delete -i 0)
    tap:assert (not-eq $err $ok)
    tap:assert-expected $stderr "you need to specify the rclone remote."
    tap:assert (not (os:is-regular $tmpdir/rclone-calls))

    teardown-env $tmpdir $old-path $old-xdg
  }]
]
