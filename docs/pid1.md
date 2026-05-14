# PID 1 Responsibilities

PID 1 is special. It is the first userspace process started by the kernel.

In a full distro, PID 1 is often `systemd`, OpenRC, runit, or another init
system. In Mentat Linux Phase II, PID 1 is the shell script at `/init`.

Current responsibilities:

- Create runtime directories.
- Mount `/proc`.
- Mount `/sys`.
- Mount `/dev`.
- Configure `/tmp` permissions.
- Configure the hostname.
- Try to initialize basic networking.
- Write boot logs.
- Start an interactive shell.
- Avoid exiting.

The last point matters: if PID 1 exits, Linux treats it as a fatal condition.
For this reason, Mentat's `/init` loops back into a shell instead of exiting.
If something important fails, it opens an emergency shell.
