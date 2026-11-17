#!/bin/bash
# pick-cli.sh — which b6p binary a pull, push or audit of one org needs while the git-only web
# release reaches namespaces one at a time. Temporary: removed with b6p-legacy once every
# namespace has the release.
#
#   pick-cli.sh --url <DAV URL>                          a pull: the host is in the URL
#   pick-cli.sh --folder <path to U######/<Component>>   a push or audit of a pulled folder
#
# Prints one line, "<cli> <host> <server version>", where <cli> is:
#   b6p          b6p 1.0: the org serves 26.11.17.00 or later, or the folder's draft/ is a git
#                clone (only b6p 1.0 makes one), which always takes b6p 1.0
#   b6p-legacy   b6p 0.8.2: the org serves an earlier release (no git publishing for scripts)
#   ask          the version could not be read or is not a release tag; the line says why
# Exit 0 for b6p and b6p-legacy, 2 for ask, 64 for bad arguments.
#
# The host of a pulled folder comes from b6p's own store, ~/.b6p/state.json, key b6p:u_cache,
# entry U###### (both b6p 0.8.2 and 1.0 write it). The version comes from GET
# https://<host>/appinfo/version, which answers without a sign-in.
# For tests: B6P_SERVER_VERSION skips the HTTP read; B6P_STATE_FILE points at another store.

FLOOR="26.11.17.00"
STATE="${B6P_STATE_FILE:-$HOME/.b6p/state.json}"

mode="$1"
arg="$2"
if [ -z "$arg" ] || { [ "$mode" != "--url" ] && [ "$mode" != "--folder" ]; }; then
  echo "usage: pick-cli.sh --url <DAV URL> | --folder <U######/<Component>>" >&2
  exit 64
fi

host=""
if [ "$mode" = "--url" ]; then
  host=$(printf '%s' "$arg" | sed -E 's#^[A-Za-z]+://##; s#[/?].*$##')
else
  folder="${arg%/}"
  folder=$(printf '%s' "$folder" | tr '\\' '/')
  if [ -d "$folder/draft/.git" ] || [ -f "$folder/draft/.git" ]; then
    echo "b6p - git-clone"
    exit 0
  fi
  unit=$(printf '%s' "$folder" | tr '/' '\n' | grep -E '^U[0-9]+$' | tail -n 1)
  if [ -z "$unit" ]; then
    echo "ask - no U###### folder in the path: $arg"
    exit 2
  fi
  if [ ! -f "$STATE" ]; then
    echo "ask - no b6p store at $STATE to read the host of $unit from"
    exit 2
  fi
  # The store is pretty-printed JSON; with whitespace removed the unit's entry is one match:
  # "U123456":[{"host":"x.bluestep.net","lastAccess":...}]
  host=$(tr -d ' \n\r\t' < "$STATE" | grep -o "\"$unit\":\[[^]]*\]" | grep -o '"host":"[^"]*"' | head -n 1 | sed 's/"host":"//; s/"$//')
  if [ -z "$host" ]; then
    echo "ask - $unit has no host in $STATE (pull the component with b6p first)"
    exit 2
  fi
fi

if [ -z "$host" ]; then
  echo "ask - no host in $arg"
  exit 2
fi

if [ -n "$B6P_SERVER_VERSION" ]; then
  version="$B6P_SERVER_VERSION"
else
  version=$(curl -fsS --max-time 15 "https://$host/appinfo/version" 2>/dev/null | tr -d ' \r\n\t')
fi

if [ -z "$version" ]; then
  echo "ask $host unreadable"
  exit 2
fi
if ! printf '%s' "$version" | grep -Eq '^[0-9]{2}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}$'; then
  echo "ask $host not-a-release-tag:$version"
  exit 2
fi

# Same width, zero-padded fields: a string comparison orders them by date.
if [[ "$version" < "$FLOOR" ]]; then
  echo "b6p-legacy $host $version"
else
  echo "b6p $host $version"
fi
exit 0
