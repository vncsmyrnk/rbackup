[![GitHub main branch check runs](https://img.shields.io/github/check-runs/vncsmyrnk/rbackup/main?style=plastic&logo=github&label=CI%20workflow)](https://github.com/vncsmyrnk/rbackup/actions/workflows/ci.yaml)

# rbackup

A simple backup script written on top of [`rclone`](https://rclone.org/) powered by zip, openssl and Nix ❤️

Compress and encrypt files before pushing them to a rclone remote.

## Usage

```sh
find . -type f | rbackup generate -
```

## Install

```sh
sudo make install
```

## Tests

```sh
nix develop --command make check
```

---

## AI Usage

This project uses AI as a tool to optimize and test the code. However, AI is not used to make autonomous decisions.

## Alternatives

- [restic: multiple backends, first-class support for backup restoring](https://restic.net/)
