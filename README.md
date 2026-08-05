[![GitHub main branch check runs](https://img.shields.io/github/check-runs/vncsmyrnk/rbackup/main?style=plastic&logo=github&label=CI%20workflow)](https://github.com/vncsmyrnk/rbackup/actions/workflows/ci.yaml)

# rbackup

A simple backup script written on top of [`rclone`](https://rclone.org/).

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

## Alternatives

- [restic: multiple backends, first-class support for backup restoring](https://restic.net/)
