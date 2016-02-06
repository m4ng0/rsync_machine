# Rsync-based *Time Machine*
Rsync-based "Time Machine"-like backup, using hard links.

You have to configure a server with rsyncd daemon, then copy `sample.rsync_machine` directory to `.rsync_machine` on the client (backup source host) and configure these files:

1. `backup.cfg` where you set the root directory to backup and set connection parameters; if your host is headless you should set `ZENITY` variable to `false`.
1. `excludes` where you set backup exclusion patterns.
1. `pwd`: this file contains the password to connect to rsyncd service.

In the same directory you'll find a `log` file with execution logs.
If `ZENITY` variable is set to `true` some *nice* dialog will inform you on what is going on.
