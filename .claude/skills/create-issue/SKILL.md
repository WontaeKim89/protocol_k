---
name: create-issue
description: Create a GitHub issue following the project's issue-first workflow. Also use when the user wants to checkout an existing issue branch into a worktree for isolated development. Triggers on phrases like "이슈 생성", "이슈 만들어", "issue 생성", "작업 등록", "이슈 올려줘", "이슈 N번 worktree", "이슈 N번 작업 시작", "worktree로 체크아웃", or any request to create a GitHub issue or checkout an issue branch before starting development.
---

# GitHub Issue 생성 스킬

이 프로젝트는 이슈-퍼스트 워크플로우를 따른다. 이슈를 생성하면 GitHub Actions(`auto-branches-from-issue.yml`)가 본문에서 브랜치 유형을 파싱하여 자동으로 브랜치를 생성한다. **본문 형식이 이슈 템플릿(`feature-task.yml`)의 출력과 정확히 일치해야 워크플로우가 정상 동작한다.**

결정론적인 작업은 모두 `scripts/` 의 셸 스크립트로 위임되어 있다. LLM 토큰 소비를 줄이기 위해 가능한 한 스크립트 호출을 우선한다.

## 사용자 인터랙션 원칙

사용자에게 선택지를 제안하거나 확인을 받을 때는 **`AskUserQuestion` 툴**을 사용한다.

## 보조 스크립트

| 스크립트 | 역할 | 핵심 인자 |
|----------|------|-----------|
| `scripts/wrap-issue-body.sh` | 이슈 템플릿 헤더로 본문 wrapping | `<type>` + stdin |
| `scripts/assign-sprint.sh` | 현재 Sprint 자동 배정 (날짜 비교 + project item 조회 + mutation) | `<issue-url>` |
| `scripts/checkout-issue-worktree.sh` | 연결된 브랜치를 worktree/체크아웃으로 준비 | `<issue-number> [worktree\|checkout]` |

각 스크립트는 명확한 exit code를 반환한다. 0 이외의 코드를 받으면 stderr 메시지를 사용자에게 전달하고 적절한 fallback (수동 절차) 을 제안한다.

## 스킵 로직 (이미 이슈가 존재하는 경우)

사용자가 **이슈 번호를 직접 언급**하며 체크아웃/worktree를 요청하면 (예: "이슈 123번 worktree로 체크아웃해줘"), 1~7단계를 건너뛰고 **8단계(브랜치 체크아웃)로 바로 진행**한다. `checkout-issue-worktree.sh` 가 워크플로우 미완료 상태도 exit code 2 로 알려주므로 LLM 추가 검증이 불필요하다.

## 워크플로우

### 1. 작업 내용 파악

사용자가 어떤 작업을 할 것인지 설명하면, 그 내용을 기반으로 이슈를 구성한다.

### 2. 브랜치 유형 결정

사용자와 협의하여 결정한다:
- **Feature**: 새로운 기능, 설정, 구성 추가
- **Fix**: 일반 버그 수정
- **Hotfix**: 운영/배포에 영향 있는 긴급 수정
- **Chore**: 문서 정리, 리팩토링 등 기능 변경 없는 작업

### 3. 제목 작성

- 영어로 작성 (한글 포함 금지)
- `[Feature]` 등의 prefix를 붙이지 않음 (GitHub Actions가 자동 추가)
- **40자 이내**로 짧고 구체적으로 (제목이 브랜치명 slug로 변환되므로 너무 길면 브랜치명이 불편해진다)

예시: `Add AI coding standards config`, `Fix start script npm check`

### 4. 본문 작성 (가운데 본문만)

LLM 은 "상세 요구사항 및 개발 내용" 영역의 **가운데 본문만** 작성한다. 헤더와 템플릿 wrapping 은 `wrap-issue-body.sh` 가 담당한다 (헤더의 이모티콘/공백/줄바꿈 사고를 막기 위해).

본문 작성 원칙:
- **한국어로 작성**한다 (제목은 영어, 본문은 한국어)
- 개발할 내용 중심으로 작성 (구현 상세가 아닌, 무엇을 만들겠다는 내용)
- 불필요하게 길지 않게
- 별도의 "기타 참고 사항" 이 있다면 별도 파일로 준비 (없으면 자동으로 `_No response_` 처리됨)

### 5. 사용자 검토

`wrap-issue-body.sh` 로 본문을 wrap 한 뒤, 그 결과(제목 + wrap 된 본문)를 사용자에게 보여주고 확인을 받는다. 사용자가 수정을 요청하면 반영 후 다시 wrap → 검토. 임의로 이슈를 생성하지 않는다.

### 6. 이슈 생성

사용자 확인 후 5단계에서 wrap 한 본문을 그대로 `gh issue create` 로 전달한다. `--label` 옵션은 사용하지 않는다. `--assignee @me` 로 본인을 담당자로 지정한다.

본문에 큰따옴표/백슬래시가 섞여도 안전하도록 **heredoc** 으로 stdin 을 넘긴다 (`printf "..."` 패턴은 따옴표 escape 사고 위험).

```bash
BODY=$(.claude/skills/create-issue/scripts/wrap-issue-body.sh Feature <<'EOF'
<가운데 본문 — 한국어 multi-line, 따옴표/백슬래시 모두 안전>
EOF
)
gh issue create --title "제목" --assignee @me --body "$BODY"
```

별도 "기타 참고 사항" 본문이 있다면 임시 파일로 만들어 두 번째 인자로 전달:

```bash
NOTES=$(mktemp); printf '%s\n' "$NOTES_CONTENT" > "$NOTES"
BODY=$(.claude/skills/create-issue/scripts/wrap-issue-body.sh Feature "$NOTES" <<'EOF'
...
EOF
)
rm -f "$NOTES"
```

생성 후 이슈 URL 을 사용자에게 전달한다. 본문 형식은 GitHub form 출력과 byte 단위로 동일하므로 `auto-branches-from-issue.yml` 의 awk 파서와 정확히 호환된다.

### 7. Sprint 자동 배정 + 워크플로우 polling 병렬화

이슈 생성 직후, 다음 두 가지를 **동시에** 시작한다 (병렬화로 체감 시간 단축):

**a) 워크플로우 polling — 백그라운드 (`run_in_background: true`)**

`auto-branches-from-issue.yml` 워크플로우가 브랜치를 생성할 때까지 기다리는 한 줄짜리 polling 을 백그라운드로 띄운다. 사용자에게 다음 질문/Sprint 배정을 진행하는 동안 자동으로 진행된다.

```bash
until gh run list --workflow=auto-branches-from-issue.yml --limit 1 --json status -q '.[0].status' | grep -q completed; do sleep 3; done
```

**b) Sprint 자동 배정 — foreground**

```bash
.claude/skills/create-issue/scripts/assign-sprint.sh "<ISSUE_URL>"
```

스크립트가 오늘 날짜 → 현재 Sprint 결정, project item ID 조회 (재시도 포함), Sprint 필드 mutation 까지 한 번에 처리한다. stdout 의 `ASSIGNED_SPRINT: Sprint X` 한 줄을 사용자에게 그대로 안내한다.

> Sprint 표가 갱신되어야 할 때 (스크립트가 exit 2 반환): 스크립트 내부 `SPRINT_TABLE` 변수를 직접 수정한다. SKILL.md 본문에는 표를 두지 않는다.

### 8. 브랜치 체크아웃 (개발 준비)

`AskUserQuestion` 툴로 다음 3가지 선택지를 제안한다:

1. **일반 체크아웃** — 현재 작업 디렉토리에서 브랜치 전환
2. **Worktree로 체크아웃 (권장)** — 별도 독립 디렉토리에서 브랜치 체크아웃
3. **건너뛰기** — 이슈 URL 만 안내하고 종료

선택지 1, 2 모두 `checkout-issue-worktree.sh` 가 처리한다. **호출 직전 7-(a) 백그라운드 polling 의 완료 여부를 `BashOutput` 으로 확인**한다 — 아직 진행 중이면 polling 종료를 기다린 뒤 진입한다 (그래야 polling 이 dead work 이 아니다). 이미 끝났다면 즉시 호출.

```bash
# Worktree 모드 (기본) — .claude/worktrees/issue-<번호>/ 에 생성
.claude/skills/create-issue/scripts/checkout-issue-worktree.sh <이슈번호>

# 일반 체크아웃
.claude/skills/create-issue/scripts/checkout-issue-worktree.sh <이슈번호> checkout
```

스크립트 출력에서 `CHECKOUT_PATH` (worktree 모드) / `CHECKOUT_BRANCH` 값을 사용자에게 안내한다.

**Worktree 생성 직후 작업 디렉토리 이동 (필수)**

worktree 모드일 때는 스크립트가 반환한 `CHECKOUT_PATH` 로 즉시 `cd` 한다. Claude 의 Bash 세션은 호출 간 cwd 가 유지되므로 한 번만 이동하면 이후 명령(파일 읽기/쓰기, git 등)이 모두 worktree 안에서 동작한다.

```bash
cd <CHECKOUT_PATH> && pwd && git status -sb
```

`pwd` 로 이동 성공을, `git status -sb` 출력의 `## <브랜치>` 헤더로 worktree 브랜치 컨텍스트와 변경사항 유무를 한 번에 검증한다.

완료 안내:
> "Worktree `<CHECKOUT_PATH>` 로 이동 완료. 이후 작업은 모두 이 worktree 안에서 진행됩니다."

#### 스크립트 exit code 매핑

| 스크립트 | exit | 의미 / 대응 |
|----------|------|-------------|
| `wrap-issue-body.sh` | 0 | 성공 |
|  | 1 | 인자/본문 오류 — 사용자에게 stderr 메시지 전달 후 재시도 |
| `assign-sprint.sh` | 0 | Sprint 배정 성공 |
|  | 1 | 인자/의존성 오류 |
|  | 2 | Sprint 표 갱신 필요 — 스크립트 내부 `SPRINT_TABLE` 직접 수정 |
|  | 3 | issue node ID 조회 또는 project add/update 실패 — 권한/네트워크 점검 |
| `checkout-issue-worktree.sh` | 0 | 성공 (이미 준비된 상태도 0) |
|  | 1 | 인자/의존성 오류 |
|  | 2 | 연결된 브랜치 없음 → 워크플로우 미완료. 잠시 후 재시도 안내 |
|  | 3 | git 명령 실패 → stderr 메시지 그대로 전달 |
