[![GitHub main branch check runs](https://img.shields.io/github/check-runs/vncsmyrnk/rbackup/main?style=plastic&logo=github&label=CI%20workflow)](https://github.com/vncsmyrnk/rbackup/actions/workflows/ci.yaml)

# rbackup

A simple backup script written on top of [`rclone`](https://rclone.org/).

## Install

```sh
sudo make install
```

## Running from source

```sh
nix develop --command rbackup --help
```
