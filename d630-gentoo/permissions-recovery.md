# Gentoo filesystem permission recovery

Date: 2026-11-03  
Scope: interactive Gentoo Stage 3 runner and Portage build failures

## Incident report

A Portage build of `app-text/xmlto-0.0.28-r11` failed during the compile phase on 2026-11-02. The build log records repeated:

```text
/bin/sh: line 1: /usr/bin/xmlto: Permission denied
make: *** [Makefile:25: scripts] Error 2
```

The failure occurred while `xdg-utils` generated HTML documentation. It is an execution-permission failure, not a compiler or source-code error.

The follow-up inspection found:

- `umask` was `0022`, which is normal.
- `/usr/bin/xmlto` was mode `0755`; `xmlto --version` succeeded as root during the later inspection. The original failure was therefore not reproduced.
- `findmnt -T` produced no filesystem row in the captured output. The root filesystem's mount options, including `noexec`, were not established by that command.
- `getent passwd 1001` returned no account, but access and default ACLs for numeric UID 1001 were present on `/`, `/usr`, `/usr/bin` and `/var`.
- Those directories also had permissive default ACL entries, including `default:group::rwx` and `default:other::rwx`. Such defaults can propagate unexpectedly broad permissions to newly created files and directories.
- `/var/tmp` and `/var/tmp/portage` also carried UID 1001 ACL entries and default ACLs.
- Several command files were mode `0666` (world-writable and not executable), including `/usr/bin/startx`, Byobu entry points and Eix command scripts. The `startx` file is owned by `x11-apps/xinit`.
- The scan of files without execute bits returned 240 paths. That count is **not** a count of broken executables: it also includes data files and helper scripts intentionally invoked by an interpreter.
- `/usr/bin/pon` was not claimed by Portage; the installed PPP package claims `/usr/sbin/pon`. Do not assume these paths are interchangeable.

The evidence confirms unsafe/inconsistent ACLs and several suspicious file modes. It does not establish which earlier command introduced them, whether every affected mode is wrong, or why `xmlto` was denied at the original build time. The account for UID 1001 may be stale, but confirm that UID is not intentionally reserved before removing its ACL entries.

## Immediate recovery

Do not run recursive `chmod`, `chown`, `setfacl -bR` or `setfacl -kR` across the system. These can destroy package-specific modes, setuid/setgid bits, sticky bits and legitimate ACLs.

First preserve the current ACL state and inventory the risky paths:

```bash
install -d -m 0700 /root/permission-audit-20261103
getfacl -R -P /etc /usr /var /opt /root /home \
  > /root/permission-audit-20261103/acl-before.txt

find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /usr/libexec /usr/lib/portage \
  -type f -perm -0002 -printf '%m %u:%g %p\n' 2>/dev/null | sort \
  > /root/permission-audit-20261103/world-writable-files.txt

getfacl -R -P -s /etc /usr /var /opt /root /home 2>/dev/null \
  > /root/permission-audit-20261103/nontrivial-acls.txt
```

For the two package-owned commands directly implicated in the inspection, reinstall their owning packages to restore the package-recorded files and modes:

```bash
emerge --ask --oneshot --usepkg --getbinpkg app-text/xmlto x11-apps/xinit
```

Then verify:

```bash
stat -c '%a %A %U:%G %n' /usr/bin/xmlto /usr/bin/startx
/usr/bin/xmlto --version
portageq owners / /usr/bin/xmlto /usr/bin/startx
```

Use the same package-owner lookup for other suspicious files before repairing them. Reinstall the owning package where Portage claims the path. Investigate unowned files individually; do not guess their intended mode.

## ACL remediation procedure

1. Review `acl-before.txt` and `nontrivial-acls.txt`. Identify every directory that has a default ACL and determine whether the ACL is intentional.
2. Confirm whether numeric UID 1001 is intentionally used by any service, container, shared filesystem or external identity mapping. Its absence from `getent passwd` alone does not prove that every UID 1001 ACL is disposable.
3. Remove only confirmed stale named-user entries, after preserving the ACL backup. Review access ACLs and default ACLs separately.
4. Remove permissive default ACLs only from directories confirmed to have inherited accidental defaults. Do not blindly remove all default ACLs from `/var/tmp/portage` or other service directories.
5. Reinstall affected packages after ACL remediation, then rerun the executable-mode and ACL audits.

The root-level ACL output already demonstrates that default ACL inheritance is not limited to one package. A full recursive inventory is required before applying a tree-wide change. The correct repair is to restore normal directory defaults and package-owned file metadata, not to make every file executable.

## Verification after repair

Run these checks before resuming large Portage builds:

```bash
umask
findmnt -T /usr/bin/xmlto -o TARGET,SOURCE,FSTYPE,OPTIONS
stat -c '%a %A %U:%G %n' /usr/bin/xmlto /usr/bin/startx
getfacl -p / /usr /usr/bin /var /var/tmp /var/tmp/portage
/usr/bin/xmlto --version
emerge --info
```

A successful `xmlto --version` confirms that the current shell can execute it; it does not retrospectively explain the earlier failure. If the build fails again, capture the new build log immediately, along with `stat`, `getfacl` and `findmnt -T` output for the exact executable.

