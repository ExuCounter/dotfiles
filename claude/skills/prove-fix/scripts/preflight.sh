#!/usr/bin/env bash
# Checks what a proof needs before it starts, and prints every failure at once with its fix.
#   preflight.sh [--tools <tool>...] [--glab-host <host>] [--vault <profile>]
#                [--aws-profile <profile> --kube <context>/<namespace>/<label selector>] [--url <URL>]
# --tools: each is on PATH. --glab-host: glab has a stored login there. --vault: agent-browser's auth vault
# holds the profile. --aws-profile: its SSO session works. --kube: in that context and namespace, kubectl
# may read pod logs and exec, and a running pod matches the selector, such as component=app,release=<name>. --url: it answers 2xx or 3xx.
# AWS and kubectl run with the static AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN unset
# and AWS_PROFILE set, since static keys override the SSO profile.
# Prints "ok <what>" per pass and "FAIL <what>: <fix>" per failure; exit 1 when any failed, 64 on bad arguments.
set -euo pipefail

usage() {
  echo "usage: preflight.sh [--tools <tool>...] [--glab-host <host>] [--vault <profile>] [--aws-profile <profile> --kube <context>/<namespace>/<label selector>] [--url <URL>]" >&2
  exit 64
}

named() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._@-]*$ ]]; }

tools=()
glab_host=""
vault=""
aws_profile=""
kube=""
url=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tools)
      shift
      while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do named "$1" || usage; tools+=("$1"); shift; done
      ;;
    --glab-host) [ $# -ge 2 ] && named "$2" || usage; glab_host="$2"; shift 2 ;;
    --vault) [ $# -ge 2 ] && named "$2" || usage; vault="$2"; shift 2 ;;
    --aws-profile) [ $# -ge 2 ] && named "$2" || usage; aws_profile="$2"; shift 2 ;;
    --kube) [ $# -ge 2 ] || usage; kube="$2"; shift 2 ;;
    --url) [ $# -ge 2 ] && [[ "$2" =~ ^https?://[^[:space:]]+$ ]] || usage; url="$2"; shift 2 ;;
    *) usage ;;
  esac
done
if [ -n "$kube" ]; then
  [ -n "$aws_profile" ] || usage
  IFS=/ read -r context namespace selector <<<"$kube"
  label='[A-Za-z0-9][A-Za-z0-9./_-]*=[A-Za-z0-9][A-Za-z0-9._-]*'
  named "${context:-}" && named "${namespace:-}" && [[ "${selector:-}" =~ ^$label(,$label)*$ ]] || usage
fi

failed=0
ok() { printf 'ok %s\n' "$1"; }
bad() { printf 'FAIL %s: %s\n' "$1" "$2"; failed=1; }
first_line() { head -n 1 "$1" | cut -c1-160; }
err="$(mktemp)"
trap 'rm -f "$err"' EXIT

for tool in ${tools[@]+"${tools[@]}"}; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "tool $tool"
  else
    case "$tool" in
      agent-browser) hint='`npm install -g agent-browser`' ;;
      aws) hint='`brew install awscli`' ;;
      ffmpeg|ffprobe) hint='`brew install ffmpeg`' ;;
      glab|kubectl|python3) hint="\`brew install ${tool%3}\`" ;;
      *) hint="install it" ;;
    esac
    bad "tool $tool" "not on PATH; $hint"
  fi
done

if [ -n "$glab_host" ]; then
  if env -u GITLAB_TOKEN -u GITLAB_ACCESS_TOKEN -u OAUTH_TOKEN glab auth status --hostname "$glab_host" >/dev/null 2>&1; then
    ok "glab login for $glab_host"
  else
    bad "glab login for $glab_host" "run \`glab auth login --hostname $glab_host\`"
  fi
fi

if [ -n "$vault" ]; then
  if agent-browser auth show "$vault" >/dev/null 2>&1; then
    ok "vault profile $vault"
  else
    bad "vault profile $vault" "not saved; save it once in your own terminal, so the password never reaches the agent"
  fi
fi

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
if [ -n "$aws_profile" ]; then
  export AWS_PROFILE="$aws_profile"
  aws_ok=""
  if aws sts get-caller-identity --output json --cli-connect-timeout 10 --cli-read-timeout 10 >/dev/null 2>"$err"; then
    aws_ok=1
    ok "AWS SSO session $aws_profile"
  elif grep -qiE 'could not connect|connect timeout|timed out' "$err"; then
    bad "AWS SSO session $aws_profile" "cannot reach AWS ($(first_line "$err")); check the network"
  else
    bad "AWS SSO session $aws_profile" "run \`aws sso login --profile $aws_profile\`"
  fi
fi

kube_fault() {
  if grep -qiE 'unauthorized|must be logged in|provide credentials|token has expired|sso' "$err"; then
    echo "the cluster refused the AWS session; run \`aws sso login --profile $aws_profile\`"
  elif grep -qiE 'unable to connect|i/o timeout|connection refused|no such host|deadline exceeded|timeout' "$err"; then
    echo "cannot reach the cluster; connect the VPN"
  else
    echo "kubectl failed: $(first_line "$err")"
  fi
}

if [ -n "$kube" ]; then
  where="kubectl on $context/$namespace"
  cluster() { kubectl --context "$context" --namespace "$namespace" --request-timeout=15s "$@"; }
  if [ -z "$aws_ok" ]; then
    bad "$where" "needs the AWS SSO session first"
  else
    fault=""
    for right in "get pods/log" "create pods/exec"; do
      # shellcheck disable=SC2086
      answer="$(cluster auth can-i $right 2>"$err")" || true
      if [ "${answer%% *}" = no ]; then
        fault="no right to $right in $namespace; ask for that access on $context"
        break
      elif [ "$answer" != yes ]; then
        fault="$(kube_fault)"
        break
      fi
    done
    if [ -z "$fault" ]; then
      if pods="$(cluster get pods --selector "$selector" --field-selector status.phase=Running --output name 2>"$err")"; then
        [ -n "$pods" ] || fault="no running pod matches $selector; is the branch deployed?"
      else
        fault="$(kube_fault)"
      fi
    fi
    if [ -z "$fault" ]; then ok "$where: pod logs, exec and a running pod for $selector"; else bad "$where" "$fault"; fi
  fi
fi

if [ -n "$url" ]; then
  answer="$(python3 - "$url" <<'PY'
import sys, urllib.error, urllib.request
try:
    with urllib.request.urlopen(sys.argv[1], timeout=10) as response:
        print(response.status)
except urllib.error.HTTPError as error:
    print(error.code)
except Exception as error:
    print("none", str(getattr(error, "reason", "") or error)[:160])
PY
)"
  case "$answer" in
    2??|3??) ok "$url answers $answer" ;;
    403) bad "$url" "answers 403; connect the VPN" ;;
    none*) bad "$url" "no answer (${answer#none }); connect the VPN" ;;
    *) bad "$url" "answers $answer; is it deployed?" ;;
  esac
fi

exit "$failed"
