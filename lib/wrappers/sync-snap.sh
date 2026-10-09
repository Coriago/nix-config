# Shared CLI adapter. The Rust tool owns all merging, pruning, locks, and caching.
action=${1:?expected launch, sync, or snapshot}
shift
destination=$default_snapshot
if [[ $action == snapshot ]]; then
  if [[ $snapshot_enabled != true ]]; then
    echo "$program: snapshotting is disabled" >&2
    exit 1
  fi
  if [[ $# -gt 0 && $1 != --* ]]; then destination=$1; shift; fi
fi
command=("$@")
while [[ $# -gt 0 ]]; do
  flag=${1%%=*}
  if [[ -n $flag && -n ${flags[$flag]+set} ]]; then
    key=${flags[$flag]}
    if [[ $1 == *=* ]]; then
      values[$key]=${1#*=}
    else
      shift
      if [[ $# == 0 ]]; then echo "$program: missing value for $flag" >&2; exit 2; fi
      values[$key]=$1
    fi
  elif [[ $1 == -- ]]; then
    break
  elif [[ $action != launch ]]; then
    echo "$program: unknown option $1" >&2
    exit 2
  fi
  shift
done

manifest_file=
cleanup() { if [[ -n $manifest_file ]]; then rm -f -- "$manifest_file"; fi; }
trap cleanup EXIT
# These variables belong to jq, not the shell.
# shellcheck disable=SC2016
expand='def expand: reduce ($bindings | to_entries[]) as $v (.; split("@" + $v.key + "@") | join($v.value));'
prepare() {
  local key value bindings
  local -a args=()
  for key in "${!values[@]}"; do
    value=${values[$key]}
    case ${kinds[$key]} in
      path)
        if [[ -z $value ]]; then echo "$program: empty path for $key" >&2; return 1; fi
        value=$(realpath -m -- "$value") || return ;;
      segment)
        if [[ -z $value || $value == */* || $value == . || $value == .. ]]; then
          echo "$program: $key must be a single directory name" >&2
          return 1
        fi ;;
    esac
    args+=(--arg "$key" "$value")
  done
  bindings=$(jq -n "${args[@]}" '$ARGS.named') || return
  sync_marker=$(jq -nr --argjson bindings "$bindings" --arg path "$sync_marker" "$expand"'$path | expand') || return
  # An open app should not depend on manifest generation to accept another window.
  if [[ $action != snapshot && -n $sync_marker && ( -e $sync_marker || -L $sync_marker ) ]]; then
    echo "$program: application marker exists; skipping sync: $sync_marker" >&2
    return 3
  fi
  if [[ -n $destination ]]; then destination=$(realpath -ms -- "$destination") || return; fi
  manifest_file=$(mktemp --suffix=.json) || return
  jq --argjson bindings "$bindings" --arg destination "$destination" --arg program "$program" --arg action "$action" "$expand"'
    walk(if type == "string" then expand else . end) |
    if $action == "snapshot" then
      if $destination != "" then
        if (.programs[$program].snapshot | length) != 1 then error("output override requires exactly one snapshot entry")
        else .programs[$program].snapshot[0].destination = $destination end
      else . end |
      if any(.programs[$program].snapshot[]; .destination == "") then error("supply a snapshot output path or configure snapshotFile") else . end
    else . end
  ' "$template" > "$manifest_file"
}

case $action in
  launch)
    if prepare; then
      sync-snap sync --config "$manifest_file" --program "$program" --startup ||
        echo "$program: sync failed; launching anyway (see sidecar logs)" >&2
    else
      echo "$program: sync skipped or unavailable; launching anyway" >&2
    fi
    cleanup
    trap - EXIT
    exec "${command[@]}"
    ;;
  sync|snapshot)
    prepare
    sync-snap "$action" --config "$manifest_file" --program "$program"
    ;;
  *) echo "$program: unknown action $action" >&2; exit 2 ;;
esac
