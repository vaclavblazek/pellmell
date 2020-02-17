Usage:

* `rrun.sh check`: returns 0 if being run inside sshfs mounted filesystem, 1 otherwise
* `rrus run CMDLINE`: executes CMDLINE in the current directory on the remote server; fails if not run inside `sshfs` mounted filesystem

To use for remote building add this directory (containing `rrun.sh` and `make`) into your `$PATH` **before** `/usr/bin`
