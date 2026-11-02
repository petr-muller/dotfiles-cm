#!/bin/bash
# Installed as `govulncheck` on PATH, in front of the real binary.
#
# Symbol-level scans type-check the whole dependency tree and build a call
# graph in memory, with no cache to share, so several at once across sandbox
# containers swamp the host. Run them one at a time, at low priority. The lock
# lives on a host directory mounted into every sandbox container.
real=/home/claude/.local/libexec/govulncheck
lock=/home/claude/.cache/sandbox-locks/govulncheck.lock

# Module scans and informational flags are cheap: don't queue them.
prev=
for arg in "$@"; do
    case "$arg" in
        -scan=module | --scan=module | -version | --version | -h | -help | --help)
            exec "$real" "$@"
            ;;
        module)
            case "$prev" in
                -scan | --scan) exec "$real" "$@" ;;
            esac
            ;;
    esac
    prev=$arg
done

# stderr only: stdout may be `-format json` output redirected to a file.
flock -n "$lock" true ||
    echo "govulncheck: waiting for a scan in another sandbox to finish..." >&2

# --close: the lock stays with flock itself, so a background process left by a
# child (go's telemetry sidecar) can't inherit it and hold it after the scan.
exec flock --close "$lock" nice -n 10 "$real" "$@"
