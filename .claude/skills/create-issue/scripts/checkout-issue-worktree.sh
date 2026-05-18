#!/bin/sh
# 이슈에 연결된 브랜치를 worktree (또는 일반 체크아웃) 로 한 번에 준비한다.
# 사용법:
#   checkout-issue-worktree.sh <issue-number> [mode]
#     mode = worktree (기본) | checkout
#
# 동작:
#   1) gh issue develop --list <이슈번호> -> 첫 브랜치명 추출
#   2) git fetch origin
#   3) mode=worktree: <main-worktree>/.claude/worktrees/issue-<번호> 에 worktree 생성
#      mode=checkout: 현재 디렉토리에서 git checkout
#   4) 결과 경로/브랜치를 stdout 으로 안내
#
# idempotent:
#   - 로컬 브랜치가 이미 있으면 -b 옵션 없이 add
#   - worktree 경로가 이미 존재하면 기존 경로를 그대로 안내 (재생성하지 않음)
#
# 출력 (stdout):
#   CHECKOUT_BRANCH: <branch>
#   CHECKOUT_PATH: <absolute-path>     (worktree 모드일 때만)
#   CHECKOUT_MODE: worktree | checkout
#
# Exit code:
#   0   성공 (이미 준비된 상태도 0)
#   1   인자/의존성 오류
#   2   이슈에 연결된 브랜치를 찾지 못함 (워크플로우 미완료 가능)
#   3   git 명령 실패

set -e

ISSUE_NUMBER="${1:-}"
MODE="${2:-worktree}"

if [ -z "$ISSUE_NUMBER" ]; then
  echo "Usage: $0 <issue-number> [worktree|checkout]" >&2
  exit 1
fi

case "$MODE" in
  worktree|checkout)
    ;;
  *)
    echo "FAIL: mode 는 worktree | checkout 중 하나여야 합니다 (입력: '$MODE')." >&2
    exit 1
    ;;
esac

if ! command -v gh >/dev/null 2>&1; then
  echo "FAIL: gh CLI 가 필요합니다." >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "FAIL: git 이 필요합니다." >&2
  exit 1
fi

# --- 1. 연결된 브랜치 조회 ---
BRANCH=$(gh issue develop --list "$ISSUE_NUMBER" 2>/dev/null | awk -F'\t' 'NR==1 {print $1}')

if [ -z "$BRANCH" ]; then
  echo "FAIL: 이슈 #$ISSUE_NUMBER 에 연결된 브랜치를 찾지 못했습니다." >&2
  echo "  -> auto-branches-from-issue.yml 워크플로우가 아직 끝나지 않았을 수 있습니다." >&2
  echo "  -> 워크플로우 완료 후 다시 시도하세요." >&2
  exit 2
fi

# --- 2. fetch ---
if ! git fetch origin "$BRANCH" >/dev/null 2>&1; then
  # 일부 환경에서 단일 ref fetch 가 실패하면 전체 fetch 로 폴백
  if ! git fetch origin >/dev/null 2>&1; then
    echo "FAIL: git fetch origin 에 실패했습니다." >&2
    exit 3
  fi
fi

# --- 3. 모드별 처리 ---
if [ "$MODE" = "checkout" ]; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH" >/dev/null 2>&1 || { echo "FAIL: git checkout $BRANCH 실패" >&2; exit 3; }
  else
    git checkout -b "$BRANCH" "origin/$BRANCH" >/dev/null 2>&1 \
      || { echo "FAIL: git checkout -b $BRANCH origin/$BRANCH 실패" >&2; exit 3; }
  fi
  echo "CHECKOUT_BRANCH: $BRANCH"
  echo "CHECKOUT_MODE: checkout"
  exit 0
fi

# worktree 모드
# 호출 위치(메인 worktree | 다른 worktree) 와 관계없이 main worktree 기준으로 경로 계산.
# 정책: <main-worktree>/.claude/worktrees/issue-<번호>/ (.gitignore 등록됨, 상위 디렉토리 오염 방지)
MAIN_WORKTREE=$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')
if [ -z "$MAIN_WORKTREE" ]; then
  echo "FAIL: main worktree 경로를 결정하지 못했습니다." >&2
  exit 3
fi
TARGET_ABS="$MAIN_WORKTREE/.claude/worktrees/issue-${ISSUE_NUMBER}"

# (a) 동일 경로에 worktree 가 이미 등록되어 있으면 그대로 안내
if git worktree list --porcelain | awk '/^worktree / {print $2}' | grep -Fxq "$TARGET_ABS"; then
  echo "CHECKOUT_BRANCH: $BRANCH"
  echo "CHECKOUT_PATH: $TARGET_ABS"
  echo "CHECKOUT_MODE: worktree"
  echo "NOTE: 기존 worktree 를 재사용합니다."
  exit 0
fi

# (b) 같은 브랜치가 이미 다른 worktree 에서 사용 중이면 그 경로 안내
EXISTING_WT=$(git worktree list --porcelain | awk -v b="refs/heads/$BRANCH" '
  /^worktree / {wt=$2}
  /^branch / && $2==b {print wt; exit}
')
if [ -n "$EXISTING_WT" ]; then
  echo "CHECKOUT_BRANCH: $BRANCH"
  echo "CHECKOUT_PATH: $EXISTING_WT"
  echo "CHECKOUT_MODE: worktree"
  echo "NOTE: 동일 브랜치가 이미 다른 worktree 에서 사용 중입니다. 해당 경로를 사용하세요."
  exit 0
fi

# (c) 경로가 비어있지 않은데 worktree 등록은 안 된 상태 -> 사용자 개입 필요
if [ -e "$TARGET_ABS" ]; then
  echo "FAIL: 경로 '$TARGET_ABS' 가 이미 존재하지만 worktree 로 등록되어 있지 않습니다." >&2
  echo "  -> 직접 정리하거나 다른 경로를 지정해야 합니다." >&2
  exit 3
fi

# 로컬 브랜치 존재 여부에 따라 옵션 분기
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  if ! git worktree add "$TARGET_ABS" "$BRANCH" >/dev/null 2>&1; then
    echo "FAIL: git worktree add $TARGET_ABS $BRANCH 실패" >&2
    exit 3
  fi
else
  if ! git worktree add -b "$BRANCH" "$TARGET_ABS" "origin/$BRANCH" >/dev/null 2>&1; then
    echo "FAIL: git worktree add -b $BRANCH $TARGET_ABS origin/$BRANCH 실패" >&2
    exit 3
  fi
fi

echo "CHECKOUT_BRANCH: $BRANCH"
echo "CHECKOUT_PATH: $TARGET_ABS"
echo "CHECKOUT_MODE: worktree"
exit 0
