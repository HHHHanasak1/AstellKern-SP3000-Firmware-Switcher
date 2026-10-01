#!/system/bin/sh
# modelconf.sh - dump, verify and (from the installer only) write the SP3000 modelconf partition.
#
# This file is both a library (sourced by install.sh) and a stand-alone tool:
#   su -c sh modelconf.sh dump            dump the CURRENT modelconf of this device
#   su -c sh modelconf.sh verify FILE...  check images (size, layout, sha256 pin)
#   su -c sh modelconf.sh info            show the partition and the image folder
# The stand-alone tool never writes a partition. Writing is done only by install.sh,
# after the user confirmed it with the volume keys.
#
# No Astell&Kern data ships with this module. The images come from the user's own
# device(s); see README. Only their sha256 values are listed in modelconf.sha256.

MC_SIZE=1048576  # fixed size of the partition and of every image
MC_BYNAME=${MC_BYNAME:-/dev/block/bootdevice/by-name/modelconf}
MC_PROJECT=sp3000
# Images supplied by the user: internal storage (both spellings of the same folder).
MC_IMGDIRS=${MC_IMGDIRS:-"/data/media/0/SP3000-modelconf /sdcard/SP3000-modelconf"}
# Root-only state: backups and the user's own pins (hashes of images dumped on this device).
MC_STATE=${MC_STATE:-/data/adb/sp3k_modelconf}
MC_USERPINS=${MC_USERPINS:-$MC_STATE/user.sha256}

command -v say >/dev/null 2>&1 || say() { echo "$1"; }

mc_sha256() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

mc_size() { wc -c < "$1" 2>/dev/null | tr -d ' '; }

# Count of bytes that are not NUL in a stream.
mc_nonzero() { tr -d '\000' | wc -c | tr -d ' '; }

# mc_country FILE -> prints the country value (e.g. CN.GD) if FILE has the modelconf layout:
#   exactly 1 MiB, "androidboot.device.country=<CC>[.<VAR>]", optional trailing newlines,
#   then zero bytes up to the end. Returns 1 otherwise.
mc_country() {
    f=$1
    [ -f "$f" ] || [ -b "$f" ] || return 1
    if [ -b "$f" ]; then
        tmpc=$MC_STATE/.probe.$$
        mkdir -p "$MC_STATE" || return 1
        dd if="$f" of="$tmpc" bs=4096 count=$((MC_SIZE / 4096)) 2>/dev/null || { rm -f "$tmpc"; return 1; }
        mc_country "$tmpc"; r=$?; rm -f "$tmpc"; return $r
    fi
    [ "$(mc_size "$f")" = "$MC_SIZE" ] || return 1
    len=$(head -c 64 "$f" | mc_nonzero)
    [ "$len" -gt 0 ] 2>/dev/null || return 1
    # no NUL inside the text, nothing but NUL after it
    [ "$(head -c "$len" "$f" | mc_nonzero)" = "$len" ] || return 1
    [ "$(tail -c +$((len + 1)) "$f" | mc_nonzero)" = "0" ] || return 1
    nl=$(head -c "$len" "$f" | tr -cd '\n' | wc -c | tr -d ' ')
    txt=$(head -c "$len" "$f" | tr -d '\n')
    # newlines are allowed only at the end
    [ $(( $(printf '%s' "$txt" | wc -c) + nl )) -eq "$len" ] || return 1
    [ "$(head -c "$((len - nl))" "$f" | tr -cd '\n' | wc -c | tr -d ' ')" = "0" ] || return 1
    echo "$txt" | grep -qE '^androidboot\.device\.country=[A-Z]{2}(\.[A-Z]{2,4})?$' || return 1
    echo "${txt#androidboot.device.country=}"
}

# mc_pin_label HASH -> name of the pin (builtin or user) or nothing.
mc_pin_label() {
    h=$1
    for p in "$MC_PINS" "$MC_USERPINS"; do
        [ -n "$p" ] && [ -f "$p" ] || continue
        l=$(grep -E "^$h[[:space:]]" "$p" 2>/dev/null | head -n1 | sed -E 's/^[0-9a-f]+[[:space:]]+\*?//')
        [ -n "$l" ] && { echo "$l"; return 0; }
    done
    return 1
}

# mc_verify FILE -> 0 if FILE may be written: right size, modelconf layout, sha256 pinned.
# Prints "<country> <sha256> <pin label>" on success, a reason on failure (stderr).
mc_verify() {
    f=$1
    [ -f "$f" ] || { echo "not a file: $f" >&2; return 1; }
    s=$(mc_size "$f")
    [ "$s" = "$MC_SIZE" ] || { echo "wrong size $s (need $MC_SIZE): $f" >&2; return 1; }
    c=$(mc_country "$f") || { echo "not a modelconf image (layout): $f" >&2; return 1; }
    h=$(mc_sha256 "$f")
    [ -n "$h" ] || { echo "sha256 failed: $f" >&2; return 1; }
    l=$(mc_pin_label "$h") || { echo "sha256 not pinned ($h): $f" >&2; return 1; }
    echo "$c $h $l"
}

# mc_partition -> prints the resolved block device of modelconf after checking it is
# the real modelconf partition of an SP3000 (PARTNAME and size from sysfs).
mc_partition() {
    [ -b "$MC_BYNAME" ] || { echo "no block device at $MC_BYNAME" >&2; return 1; }
    dev=$(readlink -f "$MC_BYNAME")
    [ -b "$dev" ] || { echo "cannot resolve $MC_BYNAME" >&2; return 1; }
    b=${dev##*/}
    ue=/sys/class/block/$b/uevent
    pn=$(grep '^PARTNAME=' "$ue" 2>/dev/null | cut -d= -f2)
    [ "$pn" = "modelconf" ] || { echo "$dev: PARTNAME is '$pn', not modelconf" >&2; return 1; }
    sec=$(cat /sys/class/block/$b/size 2>/dev/null)
    [ $((sec * 512)) -eq "$MC_SIZE" ] 2>/dev/null || { echo "$dev: size $((sec * 512)) != $MC_SIZE" >&2; return 1; }
    echo "$dev"
}

mc_project_ok() { [ "$(getprop ro.boot.project_name 2>/dev/null)" = "$MC_PROJECT" ]; }

# mc_dump DEST -> copy the current partition to DEST and check the copy.
mc_dump() {
    dest=$1
    dev=$(mc_partition) || return 1
    mkdir -p "${dest%/*}" || return 1
    dd if="$dev" of="$dest" bs=4096 count=$((MC_SIZE / 4096)) 2>/dev/null || return 1
    sync
    [ "$(mc_size "$dest")" = "$MC_SIZE" ] || { echo "dump has wrong size" >&2; return 1; }
    pd=$MC_STATE/.pd.$$
    dd if="$dev" of="$pd" bs=4096 count=$((MC_SIZE / 4096)) 2>/dev/null
    a=$(mc_sha256 "$pd"); rm -f "$pd"
    [ "$a" = "$(mc_sha256 "$dest")" ] || { echo "dump differs from partition" >&2; return 1; }
    return 0
}

# mc_backup -> back up the current partition to MC_STATE/backup (root-only) and to the
# image folder, pin it as the user's own image. Prints the backup path.
mc_backup() {
    ts=$(date +%Y%m%d-%H%M%S)
    mkdir -p "$MC_STATE/backup" || return 1
    chmod 700 "$MC_STATE"
    tmpb=$MC_STATE/backup/.new.$$
    mc_dump "$tmpb" || { rm -f "$tmpb"; return 1; }
    c=$(mc_country "$tmpb") || c=UNKNOWN
    h=$(mc_sha256 "$tmpb")
    # same content already backed up: keep the old file
    old=$(grep -E "^$h[[:space:]]" "$MC_USERPINS" 2>/dev/null | head -n1 | sed -E 's/.* //')
    if [ -n "$old" ] && [ -f "$MC_STATE/backup/$old" ] && [ "$(mc_sha256 "$MC_STATE/backup/$old")" = "$h" ]; then
        rm -f "$tmpb"; echo "$MC_STATE/backup/$old"; return 0
    fi
    name=modelconf_backup_$(echo "$c" | tr -d .)_$ts.bin
    mv "$tmpb" "$MC_STATE/backup/$name" || return 1
    if [ "$c" != UNKNOWN ] && ! grep -q "^$h" "$MC_USERPINS" 2>/dev/null; then
        echo "$h  own-device dump ($c) $name" >> "$MC_USERPINS"
    fi
    for d in $MC_IMGDIRS; do
        [ -d "${d%/*}" ] || continue
        mkdir -p "$d/backup" 2>/dev/null && cp "$MC_STATE/backup/$name" "$d/backup/$name" 2>/dev/null && break
    done
    echo "$MC_STATE/backup/$name"
}

# mc_write IMAGE -> write a verified image. Caller must have asked the user first.
# Backs up first, writes, reads back; on a read-back mismatch restores the backup.
mc_write() {
    img=$1
    mc_project_ok || { echo "ro.boot.project_name is '$(getprop ro.boot.project_name)', not $MC_PROJECT: refusing" >&2; return 1; }
    v=$(mc_verify "$img") || return 1
    dev=$(mc_partition) || return 1
    mc_country "$dev" >/dev/null || { echo "current $dev does not look like a modelconf: refusing to overwrite" >&2; return 1; }
    bk=$(mc_backup) || { echo "backup failed: nothing written" >&2; return 1; }
    say "  Backup: $bk"
    want=$(mc_sha256 "$img")
    dd if="$img" of="$dev" bs=4096 count=$((MC_SIZE / 4096)) conv=fsync 2>/dev/null || dd if="$img" of="$dev" bs=4096 count=$((MC_SIZE / 4096)) 2>/dev/null
    sync
    rb=$MC_STATE/.rb.$$
    dd if="$dev" of="$rb" bs=4096 count=$((MC_SIZE / 4096)) 2>/dev/null
    got=$(mc_sha256 "$rb"); rm -f "$rb"
    if [ "$got" != "$want" ]; then
        echo "READ-BACK MISMATCH ($got != $want), restoring backup" >&2
        dd if="$bk" of="$dev" bs=4096 count=$((MC_SIZE / 4096)) 2>/dev/null; sync
        return 2
    fi
    return 0
}

# mc_find_images DIR... -> list candidate image files (one per line).
mc_find_images() {
    for d in "$@"; do
        [ -d "$d" ] || continue
        for f in "$d"/*.bin "$d"/backup/*.bin; do
            [ -f "$f" ] && echo "$f"
        done
    done
}

mc_main() {
    MC_PINS=${MC_PINS:-${0%/*}/modelconf.sha256}
    [ "$(id -u)" = 0 ] || { echo "run as root (su)"; return 1; }
    case "$1" in
        dump)
            mc_project_ok || echo "warning: ro.boot.project_name is not $MC_PROJECT"
            p=$(mc_backup) || { echo "dump failed"; return 1; }
            c=$(mc_country "$p") || c="(not a modelconf layout!)"
            h=$(mc_sha256 "$p")
            echo "dumped: $p"
            echo "country: $c"
            echo "sha256: $h"
            l=$(MC_USERPINS=/dev/null mc_pin_label "$h") && echo "matches builtin pin: $l" || echo "not a builtin pin: pinned as your own device image in $MC_USERPINS"
            for d in $MC_IMGDIRS; do [ -d "$d/backup" ] && { echo "copy: $d/backup/${p##*/}"; break; }; done
            ;;
        verify)
            shift; rc=0
            for f in "$@"; do
                if v=$(mc_verify "$f"); then echo "OK   $f: $v"; else rc=1; fi
            done
            return $rc ;;
        info)
            dev=$(mc_partition) && echo "partition: $MC_BYNAME -> $dev (1 MiB, PARTNAME=modelconf)"
            [ -n "$dev" ] && echo "current: $(mc_country "$dev" || echo '(not a modelconf layout)')"
            echo "project: $(getprop ro.boot.project_name)"
            echo "images:"; mc_find_images $MC_IMGDIRS | while read -r f; do
                v=$(mc_verify "$f" 2>&1) && echo "  OK  $f: $v" || echo "  --  $v"; done
            ;;
        *) echo "usage: sh $0 dump | verify FILE... | info"; return 1 ;;
    esac
}

case "${0##*/}" in modelconf.sh) mc_main "$@" ;; esac
