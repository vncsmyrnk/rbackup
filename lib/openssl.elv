var openssl-flags = [-aes-256-cbc -pbkdf2 -iter 100000 -salt]

fn encrypt {|src-file dest-file password|
  echo $password | openssl enc $@openssl-flags ^
    -in $src-file ^
    -out $dest-file ^
    -pass stdin
}

fn decrypt {|src-file dest-file password|
  echo $password | openssl enc -d $@openssl-flags ^
    -in $src-file ^
    -out $dest-file ^
    -pass stdin
}

