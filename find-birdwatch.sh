#!/usr/bin/env bash
#
# find-birdwatch.sh — locate BirdWatchAI Server instances on your local network.
#
# When http://birdwatch.local:8080 won't resolve (some networks block the mDNS
# ".local" name) and your Pi is headless so there's no screen to read the IP
# off, run this from any Mac or Linux box on the same network. It scans the
# local subnet for anything answering on the BirdWatchAI port, confirms each hit
# by calling /api/status, and prints the dashboard URL(s).
#
# Nothing is installed and nothing leaves your machine — it only talks to hosts
# on your own LAN.
#
# Usage:
#   ./find-birdwatch.sh                 # auto-detect subnet, scan it
#   PORT=8080 ./find-birdwatch.sh       # override the port
#   SUBNET=192.168.1 ./find-birdwatch.sh   # force a /24 prefix
#   TIMEOUT=1.5 ./find-birdwatch.sh     # more forgiving per-host timeout (seconds)
#
# Requires: bash + curl (both present by default on macOS and virtually all
# Linux distros). Uses xargs -P for a fast parallel scan.

set -u

PORT="${PORT:-8080}"
TIMEOUT="${TIMEOUT:-0.6}"   # per-host connect timeout, seconds
PARALLEL="${PARALLEL:-64}"  # concurrent probes

# --- detect the local /24 prefix(es) --------------------------------------
detect_prefixes() {
    local ips=""
    if command -v ip >/dev/null 2>&1; then
        # Linux (iproute2)
        ips="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"
    fi
    if [ -z "$ips" ] && command -v ifconfig >/dev/null 2>&1; then
        # macOS / BSD / older Linux
        ips="$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | sed 's/addr://')"
    fi
    printf '%s\n' "$ips" \
        | grep -vE '^(127\.|169\.254\.|$)' \
        | awk -F. 'NF==4 {print $1"."$2"."$3}' \
        | sort -u
}

# --- probe one host: TCP-connect, then fingerprint via /api/status --------
# Exported so xargs' subshells can call it. Prints "IP|<status-json>" on a hit.
probe_host() {
    local ip="$1" port="$2" timeout="$3"
    local body
    body="$(curl -fsS -m 3 --connect-timeout "$timeout" "http://${ip}:${port}/api/status" 2>/dev/null)" || return 0
    # EngineStatus JSON always carries these two fields — a fingerprint nothing
    # else on a home LAN will have.
    case "$body" in
        *'"detectionsToday"'*) case "$body" in *'"cameraConnected"'*) printf '%s|%s\n' "$ip" "$body" ;; esac ;;
    esac
}
export -f probe_host

# --- pull a field out of the tiny status JSON without needing jq ----------
json_field() {
    # json_field <json> <key>  → best-effort scalar extraction
    printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^,\"}]*\).*/\1/p" | head -n1
}

echo ""
echo "BirdWatchAI Server finder"
echo "-------------------------"

if ! command -v curl >/dev/null 2>&1; then
    echo "This script needs 'curl', which isn't installed." >&2
    echo "Install it (e.g. 'sudo apt install curl') and try again." >&2
    exit 1
fi

if [ -n "${SUBNET:-}" ]; then
    prefixes="${SUBNET%.}"
else
    prefixes="$(detect_prefixes)"
fi

if [ -z "$prefixes" ]; then
    echo "Couldn't determine your local network. Pass one explicitly, e.g.:" >&2
    echo "    SUBNET=192.168.1 ./find-birdwatch.sh" >&2
    exit 1
fi

printf 'Scanning'
for p in $prefixes; do printf ' %s.0/24' "$p"; done
printf ' on port %s ...\n' "$PORT"

# Build the full target list, then fan out with xargs -P.
targets_file="$(mktemp)"
trap 'rm -f "$targets_file"' EXIT
for prefix in $prefixes; do
    for n in $(seq 1 254); do
        printf '%s.%s\n' "$prefix" "$n"
    done
done > "$targets_file"

hits="$(xargs -P "$PARALLEL" -I{} bash -c 'probe_host "$1" "$2" "$3"' _ {} "$PORT" "$TIMEOUT" < "$targets_file")"

echo ""
if [ -z "$hits" ]; then
    echo "No BirdWatchAI servers found on your network."
    echo ""
    echo "Things to check:"
    echo "  * Is the Pi powered on and on the SAME network as this computer?"
    echo "    (A 'Guest' Wi-Fi or a work VPN often can't see it.)"
    echo "  * Give it more time on slow Wi-Fi:  TIMEOUT=1.5 ./find-birdwatch.sh"
    echo "  * If your network isn't a /24, force it:  SUBNET=10.1.2 ./find-birdwatch.sh"
    echo "  * Last resort: your router's admin page lists connected devices by name."
    exit 2
fi

count="$(printf '%s\n' "$hits" | grep -c '|')"
if [ "$count" -eq 1 ]; then
    echo "Found 1 BirdWatchAI server:"
else
    echo "Found $count BirdWatchAI servers:"
fi
echo ""

# Print numbered results and remember URLs for the open prompt.
i=0
urls=()
while IFS='|' read -r ip json; do
    [ -z "$ip" ] && continue
    i=$((i + 1))
    url="http://${ip}:${PORT}"
    urls+=("$url")
    cam="$(json_field "$json" cameraConnected)"
    dets="$(json_field "$json" detectionsToday)"
    state="$(json_field "$json" state)"
    feeder="$(json_field "$json" feederName)"
    hostn="$(json_field "$json" hostname)"
    [ "$cam" = "true" ] && cam="Connected" || cam="Disconnected"
    # feederName/hostname are only present on newer servers, or may be JSON null.
    [ "$feeder" = "null" ] && feeder=""
    [ "$hostn" = "null" ] && hostn=""

    # Headline with the feeder name if set; otherwise lead with the URL.
    if [ -n "$feeder" ]; then
        echo "  [$i] $feeder"
        echo "      $url"
    else
        echo "  [$i] $url"
    fi
    # Detail line — prefix the host name when we have a real one (reachable as <hostname>.local).
    prefix=""
    [ -n "$hostn" ] && prefix="host: ${hostn}   "
    echo "      ${prefix}camera: ${cam}   detections today: ${dets:-?}   monitoring: ${state:-?}"
done <<EOF
$hits
EOF
echo ""

# Offer to open one in the default browser.
opener=""
if command -v open >/dev/null 2>&1; then opener="open"          # macOS
elif command -v xdg-open >/dev/null 2>&1; then opener="xdg-open" # Linux desktop
fi

if [ -n "$opener" ] && [ -t 0 ]; then
    if [ "${#urls[@]}" -eq 1 ]; then
        printf 'Open it in your browser? [Y/n] '
        read -r ans
        case "$ans" in ''|y|Y|yes|YES) "$opener" "${urls[0]}" >/dev/null 2>&1 & ;; esac
    else
        printf 'Open which one? [1-%s, or Enter to skip] ' "${#urls[@]}"
        read -r ans
        case "$ans" in
            ''|*[!0-9]*) : ;;
            *) idx=$((ans - 1)); [ "$idx" -ge 0 ] && [ "$idx" -lt "${#urls[@]}" ] && "$opener" "${urls[$idx]}" >/dev/null 2>&1 & ;;
        esac
    fi
fi

echo ""
echo "Tip: bookmark the address above so you don't have to scan again."
echo "If the IP keeps changing, reserve it for the Pi in your router's DHCP settings."
