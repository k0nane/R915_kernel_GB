#!/sbin/sh
# Custom initscript by DRockstar, modified by k0nane
# called by init.rc

# busybox command variables
BUSYBOX="/sbin/busybox"

AWK="$BUSYBOX awk"
CHMOD="$BUSYBOX chmod"
CHOWN="$BUSYBOX chown"
CP="$BUSYBOX cp"
DF="$BUSYBOX df"
ECHO="$BUSYBOX echo"
FIND="$BUSYBOX find"
GREP="$BUSYBOX grep"
LN="$BUSYBOX ln"
MOUNT="$BUSYBOX mount"
MV="$BUSYBOX mv"
READLINK="$BUSYBOX readlink"
RM="$BUSYBOX rm"
TEST="$BUSYBOX test"

# Clean all root/busybox files is /sdcard/exists
if $TEST -e /sdcard/rootcleaner; then
  /sbin/rootcleaner
  $MV -f /sdcard/rootcleaner /sdcard/rootcleaner.hold
fi

# Remount filesystems RW
$MOUNT -o remount,rw /
$MOUNT -o remount,rw /system

# Install busybox and clean prior links if not detected
busyboxtest=""
$TEST -f /system/bin/busybox -o -f /system/xbin/busybox || busyboxtest="true"
$TEST -f /system/bin/zcat -o -f /system/xbin/zcat || busyboxtest="true"
if $TEST "$busyboxtest" != ""; then
  for dir in bin xbin; do
    for link in `$FIND /system/$dir -type l`; do
      linkdest="`$READLINK $link`"
      bustest="`$READLINK $link | $GREP busybox`"
      rectest="`$READLINK $link | $GREP recovery`"
      if $TEST "$bustest" != "" -o "$rectest" != ""; then 
        $RM $link
        $TEST -e $linkdest -a "$linkdest" != "/sbin/busybox" && $RM $linkdest
      fi
    done
  done
  for link in `busybox --list`; do
    $LN -sf /sbin/busybox /system/xbin/$link
  done
  $LN -s /sbin/busybox /system/xbin/busybox
fi

# Remap mv link to busybox
$RM /system/bin/mv
$LN -s /sbin/busybox /system/bin/mv

sync

# Setup su binary
if $TEST ! -f /system/bin/su; then
  $RM -f /system/xbin/su
  $CP -f /sbin/root/su /system/bin/su
  $CHOWN root root /system/bin/su
  $CHMOD 06755 /system/bin/su
fi
$RM -f /bin/su
$RM -f /sbin/su

# Install Superuser.apk (only if not installed)
if $TEST ! -f /system/app/Superuser.apk -a ! -f /data/app/Superuser.apk  -a  ! -f /data/app/com.noshufou.android.su*; then
  dfsys=`$DF /system | $GREP /system | $AWK -F ' ' '{ print $4 }'`
  if $TEST $dfsys -lt 1000; then
    $CP /sbin/root/Superuser.apk /data/app/Superuser.apk
  else
    $CP /sbin/root/Superuser.apk /system/app/Superuser.apk
  fi
# remove pre-existing data (if exists)
  $TEST -d /data/data/com.noshufou.android.su && $RM -r /data/data/com.noshufou.android.su
fi
sync

# Enable init.d support
if $TEST -d /system/etc/init.d; then
  logwrapper $BUSYBOX run-parts /system/etc/init.d
fi
sync

# Fix screwy ownerships
for blip in default.prop fota.rc init init.rc lib lpm.rc recovery.rc sbin; do
  $CHOWN root.shell /$blip
  $TEST -d $blip && $CHOWN root.shell /$blip/*
done

$CHOWN root.shell /lib/modules/*

#setup proper passwd and group files for 3rd party root access
# Thanks DevinXtreme
if $TEST ! -f /system/etc/passwd; then
  $ECHO "root::0:0:root:/data/local:/system/bin/sh" > /system/etc/passwd
  $CHMOD 0666 /system/etc/passwd
fi
if $TEST ! -f /system/etc/group; then
  $ECHO "root::0:" > /system/etc/group
  $CHMOD 0666 /system/etc/group
fi

# fix busybox DNS while system is read-write
if $TEST ! -f /system/etc/resolv.conf; then
  $ECHO "nameserver 8.8.8.8" >> /system/etc/resolv.conf
  $ECHO "nameserver 8.8.4.4" >> /system/etc/resolv.conf
fi

sync

if $TEST -f /system/media/bootanimation.zip; then
  $LN -s /system/media/bootanimation.zip /system/media/sanim.zip
fi

# remount read only and continue
$MOUNT -o remount,ro /
$MOUNT -o remount,ro /system
