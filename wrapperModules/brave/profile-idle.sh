# Chromium's Linux SingletonLock is a hostname-PID symlink. Do not remove it:
# Brave owns lock cleanup. A dead local PID permits sync after a reboot/crash.
profile_dir=$1
lock="$profile_dir/SingletonLock"
if [ -L "$lock" ]; then
  owner=$(readlink -- "$lock") || exit 1
  IFS= read -r local_host < /proc/sys/kernel/hostname || exit 1
  owner_host=${owner%-*}
  owner_pid=${owner##*-}
  case "$owner_pid" in
    ''|*[!0-9]*) exit 1 ;;
  esac
  if [ "$owner_host" != "$local_host" ] || [ -d "/proc/$owner_pid" ]; then
    echo 'sync-snap: Brave profile is in use; close Brave before syncing' >&2
    exit 1
  fi
elif [ -e "$lock" ] || [ -S "$profile_dir/SingletonSocket" ]; then
  echo 'sync-snap: Brave profile lock is not idle; leaving preferences untouched' >&2
  exit 1
fi
