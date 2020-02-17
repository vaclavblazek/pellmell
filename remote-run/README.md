Usage:

* `rrun.sh check`: returns 0 if being run inside sshfs mounted filesystem, 1 otherwise
* `rrus run CMDLINE`: executes CMDLINE in the current directory on the remote server

To use for remote building create put directory with `rrun.sh` and `make` into your `$PATH`
