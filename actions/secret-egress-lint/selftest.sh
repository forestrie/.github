#!/usr/bin/env bash
# Fixture tests for secret-egress-lint (plan 2608-04 verification).
#
#   bash actions/secret-egress-lint/selftest.sh
#
# Each fixture states what it expects in its own header comment; this asserts
# it. Assertions are anchored (`grep -E` on a full annotation line, not a bare
# substring) because a lint whose tests match loosely will happily agree with a
# scanner that has stopped scanning.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="python3 ${HERE}/secret-egress-lint.py"
fails=0

expect() { # expect <label> <exit-code> <file...> -- <grep-pattern>...
  local label="$1" want="$2"
  shift 2
  local files=() pats=()
  while [ "$1" != "--" ]; do
    files+=("$HERE/fixtures/$1")
    shift
  done
  shift
  pats=("$@")

  local out status
  out=$($SCAN "${files[@]}" 2>&1) && status=0 || status=$?

  if [ "$status" -ne "$want" ]; then
    echo "FAIL ${label}: exit ${status}, expected ${want}"
    printf '%s\n' "$out" | sed 's/^/     | /'
    fails=$((fails + 1))
    return
  fi
  local p
  for p in "${pats[@]}"; do
    if ! grep -Eq -- "$p" <<<"$out"; then
      echo "FAIL ${label}: output does not match /${p}/"
      printf '%s\n' "$out" | sed 's/^/     | /'
      fails=$((fails + 1))
      return
    fi
  done
  echo "ok   ${label}"
}

expect "job-level env true positive is flagged" 1 \
  true-positive-job-level.yml -- \
  '^::error file=.*true-positive-job-level\.yml,line=[0-9]+::\[R1\] job .resolve.'

expect "step-level env true positive is flagged" 1 \
  true-positive-step-level.yml -- \
  '^::error file=.*true-positive-step-level\.yml,line=[0-9]+::\[R1\] job .build.'

expect "workflow_call re-export is flagged (R1 at the job, R2 at the boundary)" 1 \
  true-positive-workflow-call.yml -- \
  '^::error file=.*line=[0-9]+::\[R1\] job .resolve.' \
  '^::error file=.*line=[0-9]+::\[R2\] job .resolve.*workflow_call. re-exports .pem.'

expect "annotation suppresses, and surfaces its reason" 0 \
  annotated-benign.yml -- \
  '\[R1\] job .release-meta.: waived — GH_TOKEN authenticates the lookup' \
  '0 violation'

expect "the point-of-use pattern is clean" 0 \
  clean.yml -- \
  '0 violation'

expect "a mixed tree reports every hit and still fails" 1 \
  true-positive-job-level.yml annotated-benign.yml clean.yml -- \
  '\[R1\] job .resolve.' \
  '\[R1\] job .release-meta.: waived' \
  '\*\*1 violation\(s\)\*\*'

# Scanning nothing is not the same as finding nothing: an empty target is a
# broken invocation, and a lint that passes over zero files is how coverage rots.
empty=$(mktemp -d)
if $SCAN "$empty" >/dev/null 2>&1; then
  echo "FAIL empty directory was treated as a pass"
  fails=$((fails + 1))
else
  echo "ok   empty directory fails loudly"
fi
rmdir "$empty"

if [ "$fails" -eq 0 ]; then
  printf '\nALL FIXTURE ASSERTIONS PASSED\n'
else
  printf '\n%d FIXTURE ASSERTION(S) FAILED\n' "$fails"
  exit 1
fi
