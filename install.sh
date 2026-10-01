# AstellKern SP3000 Firmware Switcher
#
# No Astell&Kern partition data ships with this module. modelconf images are supplied
# by the user (dumped from his own device(s), see README) and are only written when
# their size, layout and sha256 pin check out.

# skip mount system
SKIPMOUNT=true

# sha256 of the bundled AOSP bootctl (see THIRD_PARTY_NOTICES.md)
BOOTCTL_SHA256=7609b881109a1737d168ca4f41ae1bb7b0a43cea077450ac822798e9e2f3663b

# getkey volume: 1 = Vol- (or touch), 2 = Vol+, 3 = Power
keyvolume(){
keyvl=''; keyvl=`getevent -qlc 1 | awk '{print $3}'`
if [ "$keyvl" == "KEY_VOLUMEDOWN" ] || [ "$keyvl" == "ABS_MT_TRACKING_ID" ];then
    echo 1
elif [ "$keyvl" == "KEY_VOLUMEUP" ];then
    echo 2
elif [ "$keyvl" == "KEY_POWER" ];then
    echo 3
else
    keyvolume
fi; }

say() { ui_print "$1"; }

print_modname() {
ui_print " "
ui_print "  Name: $(grep_prop name $TMPDIR/module.prop), V$(grep_prop version $TMPDIR/module.prop), ($(grep_prop versionCode $TMPDIR/module.prop))"
ui_print "  $(grep_prop description $TMPDIR/module.prop)"
ui_print "  Author: $(grep_prop author $TMPDIR/module.prop)"
ui_print " "
}

# main process
on_install() {
[ -f "$TMPDIR/modelconf.sh" ] || abort "! modelconf.sh missing from the zip"
MC_PINS=$TMPDIR/modelconf.sha256
. "$TMPDIR/modelconf.sh"

ui_print "! Use volume keys to select"
ui_print "! Cancel, press power key"
ui_print " "
ui_print "- Touch or Volume key to continue ?"
getevent -qlc 1 >&2 && ui_print "  Check OK" || abort "! Check getevent failed"
sleep 0.5

ui_print "  Checking modelconf partition"
MC_DEV=$(mc_partition 2>&1) || abort "! $MC_DEV"
ui_print "  $MC_BYNAME -> $MC_DEV (1 MiB, PARTNAME=modelconf)"
cur=$(mc_country "$MC_DEV") || cur="(not a modelconf layout)"
ui_print "  Current modelconf: $cur"
ui_print "  Project: $(getprop ro.boot.project_name)"

MC_ALLOWED=1
mc_project_ok || { MC_ALLOWED=0; ui_print "! Not an SP3000 ($MC_PROJECT): modelconf will not be written"; }
mc_country "$MC_DEV" >/dev/null || { MC_ALLOWED=0; ui_print "! Current partition content is not a modelconf: it will not be written"; }

# Always keep a copy of the current partition (also the way to obtain your own image).
if bk=$(mc_backup 2>&1); then
    ui_print "  Backup of current modelconf: $bk"
else
    MC_ALLOWED=0; ui_print "! Backup failed ($bk): modelconf will not be written"
fi

# Collect verified images: zip common/ (own build) and the image folder; one per sha256.
ui_print "  Looking for modelconf images"
LIST=$TMPDIR/mc_list; : > "$LIST"
mc_find_images "$TMPDIR" $MC_IMGDIRS "$MC_STATE" > "$TMPDIR/mc_files"
while read -r f; do
    case "$f" in *" "*) ui_print "    skipped (space in path): $f"; continue ;; esac
    if v=$(mc_verify "$f" 2>&1); then
        h=$(echo "$v" | cut -d' ' -f2)
        grep -q " $h " "$LIST" || echo "$f $v" >> "$LIST"
    else
        ui_print "    skipped: $v"
    fi
done < "$TMPDIR/mc_files"
if [ ! -s "$LIST" ]; then
    ui_print "  No verified image found. Put your images in"
    ui_print "    /sdcard/SP3000-modelconf/ (see README)"
    MC_ALLOWED=0
fi

if [ "$MC_ALLOWED" = 1 ]; then
    ui_print " "
    ui_print "  Flash modelconf: Vol+ Yes, Vol- Next (Next on every entry = no change)"
    chosen=""
    while read -r f c h l; do
        [ -n "$f" ] || continue
        ui_print "- Flash $c ?"
        ui_print "    $l"
        ui_print "    ${f##*/}"
        ui_print "  Vol+ Yes"
        ui_print "  Vol- Next"
        ui_print " "
        k=$(keyvolume < /dev/null)
        if [ "$k" == 2 ];then
            chosen=$f; break
        elif [ "$k" == 3 ];then
            abort "! Canceled"
        fi
    done < "$LIST"
    if [ -n "$chosen" ];then
        ui_print "  Writing ${chosen##*/}"
        mc_write "$chosen"; rc=$?
        if [ $rc = 0 ];then
            ui_print "  Done, read-back verified: $(mc_country "$MC_DEV")"
        elif [ $rc = 2 ];then
            abort "! Write could not be verified; the backup was written back. Do not reboot before checking: sh modelconf.sh info"
        else
            abort "! modelconf not written"
        fi
    else
        ui_print "  Skip modelconf change"
    fi
else
    ui_print "  Skip modelconf change"
fi

sleep 0.5

ui_print "  Setup bootctl binary with 0755"
if [ ! -f "$TMPDIR/bootctl" ];then
    abort "! bootctl not found"
fi
if [ "$(mc_sha256 "$TMPDIR/bootctl")" != "$BOOTCTL_SHA256" ];then
    abort "! bootctl sha256 mismatch"
fi
set_perm $TMPDIR/bootctl 0 2000 0755
ui_print "  Done"

sleep 0.5

current_slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
current_version=$(getprop ro.build.version.incremental 2>/dev/null)
if [ "$current_slot" == "_a" ];then other=1; other_s=_b; else other=0; other_s=_a; fi
$TMPDIR/bootctl is-slot-bootable $other >/dev/null 2>&1 && ob=yes || ob=no
$TMPDIR/bootctl is-slot-marked-successful $other >/dev/null 2>&1 && os=yes || os=no
ui_print "- Switch boot slot ?"
ui_print "  Current boot slot $current_slot"
ui_print "  Current firmware version $current_version"
ui_print "  Slot $other_s: bootable=$ob, marked successful=$os"
[ "$os" == "yes" ] || ui_print "  ! Slot $other_s never booted successfully; make sure it holds a firmware"
ui_print "  Vol+ Yes"
ui_print "  Vol- Skip"
ui_print " "

k=$(keyvolume)
if [ "$k" == 2 ];then
    ui_print "  Switch to slot $other_s"
    $TMPDIR/bootctl set-active-boot-slot $other || abort "! bootctl failed"
elif [ "$k" == 1 ];then
    ui_print "  Skip boot slot switch"
else
    abort "! Canceled"
fi

# set flag to remove module in next boot
ui_print "  Cleaning module context"
set_perm_recursive $MODPATH 0 0 0755 0644
touch $MODPATH/remove
touch $MODPATH/disable

# reboot system
ui_print "- Reboot system ?"
ui_print "  Vol+ Yes"
ui_print "  Vol- Reboot manually later"
ui_print " "

k=$(keyvolume)
if [ "$k" == 2 ];then
    reboot
elif [ "$k" == 1 ];then
    ui_print "  You need reboot the device manually to apply changes"
else
    abort "! Canceled"
fi
}
