---
name: create-issue
description: "Create a GitHub issue following the project's issue-first workflow. Also use when the user wants to checkout an existing issue branch into a worktree for isolated development. Triggers on phrases like '이슈 생성', '이슈 만들어', 'issue 생성', '작업 등록', '이슈 올려줘', '이슈 N번 worktree', '이슈 N번 작업 시작', 'worktree로 체크아웃', or any request to create a GitHub issue or checkout an issue branch before starting development."
---

# GitHub Issue 생성 스킬

이 프로젝트는 이슈-퍼스트 워크플로우를 따른다. 이슈를 생성하면 GitHub Actions(`auto-branches-from-issue.yml`)가 본문에서 브랜치 유형을 파싱하여 자동으로 브랜치를 생성한다. **본문 형식이 이슈 템플릿(`feature-task.yml`)의 출력과 정확히 일치해야 워크플로우가 정상 동작한다.**

## 사용자 인터랙션 원칙

사용자에게 선택지를 제안하거나 확인을 받을 때는 **`request_user_input` 툴**을 사용한다. 텍스트로 질문을 던지고 사용자의 답변을 기다리는 대신, 구조화된 선택지를 제공하여 명확한 의사결정을 유도한다.

## 스킵 로직 (이미 이슈가 존재하는 경우)

사용자가 **이슈 번호를 직접 언급**하며 체크아웃/worktree를 요청하면 (예: "이슈 123번 worktree로 체크아웃해줘"), 1~7단계를 건너뛰고 **브랜치 체크아웃 단계로 바로 진행**한다. 이슈에 연결된 브랜치가 이미 생성되어 있으면 워크플로우 대기도 스킵한다.

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

### 4. 본문 작성

이슈 템플릿의 form 출력 형식과 **정확히** 일치해야 한다. 헤더의 이모티콘, 공백, 줄바꿈을 그대로 유지한다. GitHub Actions의 awk 파서가 `### 🌿 브랜치 유형` 헤더를 찾아 그 아래 첫 번째 비공백 줄을 브랜치 유형으로 추출한다.

```
### 🌿 브랜치 유형

{Feature | Fix | Hotfix | Chore}

### 📝 상세 요구사항 및 개발 내용

{무엇을 왜 개발하는지 간결하게 서술}
{구체적인 작업 항목을 불릿으로 나열}

### 💬 기타 참고 사항

{참고할 링크나 문서. 없으면 "_No response_"}
```

본문 작성 원칙:
- **한국어로 작성**한다 (제목은 영어, 본문은 한국어)
- 개발할 내용 중심으로 작성 (구현 상세가 아닌, 무엇을 만들겠다는 내용)
- 불필요하게 길지 않게
- "기타 참고 사항"에 내용이 없으면 `_No response_`로 채운다
- 단, 헤더(`### 🌿 브랜치 유형`, `### 📝 상세 요구사항 및 개발 내용` 등)와 브랜치 유형(`Feature`, `Fix` 등)은 템플릿 원문 그대로 유지한다

### 5. 사용자 검토

이슈를 생성하기 전에 반드시 제목과 본문을 사용자에게 보여주고 확인을 받는다. 사용자가 수정을 요청하면 반영 후 다시 확인받는다. 임의로 이슈를 생성하지 않는다.

### 6. 이슈 생성

사용자 확인 후 `gh issue create`를 실행한다. `--label` 옵션은 사용하지 않는다. `--assignee @me`로 본인을 담당자로 지정한다.

```bash
gh issue create --title "제목" --assignee @me --body "$(cat <<'EOF'
### 🌿 브랜치 유형

Feature

### 📝 상세 요구사항 및 개발 내용

작업 내용 기술

### 💬 기타 참고 사항

_No response_
EOF
)"
```

생성 후 이슈 URL을 사용자에게 전달한다.

### 7. 브랜치 체크아웃 (개발 준비)

이슈가 생성되면 `auto-branches-from-issue.yml` 워크플로우가 원격에 브랜치를 자동 생성한다. **이 단계를 진행하기 전에 `request_user_input` 툴로 체크아웃 방식을 선택받는다.**

`request_user_input`으로 다음 3가지 선택지를 제안한다:

1. **일반 체크아웃** — 현재 작업 디렉토리에서 브랜치 전환 (다른 작업이 없을 때 적합)
2. **Worktree로 체크아웃** — 별도 독립 디렉토리에서 브랜치 체크아웃 (현재 작업에 영향 없음)
3. **건너뛰기** — 이슈 URL만 안내하고 종료

#### 공통 절차 (일반 체크아웃, Worktree 모두)

1. **워크플로우 완료 대기**: GitHub Actions 워크플로우가 브랜치를 생성할 때까지 기다린다.
   ```bash
   gh run list --workflow=auto-branches-from-issue.yml --limit 1
   ```
   - `completed` 상태가 될 때까지 확인한다.
   - 최대 60초 정도 소요될 수 있다.

2. **연결된 브랜치 확인**: 이슈에 연결된 브랜치명을 조회한다.
   ```bash
   gh issue develop --list <이슈번호>
   ```

3. **원격 브랜치 fetch**:
   ```bash
   git fetch origin
   ```

#### 옵션 A: 일반 체크아웃

```bash
git checkout <브랜치명>
git branch --show-current
git status
```
> "브랜치 `<브랜치명>`에서 개발 준비가 완료되었습니다."

#### 옵션 B: Worktree로 체크아웃

현재 다른 브랜치에서 작업 중일 때 유용하다. 독립된 디렉토리에 브랜치를 체크아웃하므로 현재 작업에 영향을 주지 않는다.

**주의: 반드시 `gh issue develop --list`로 조회한 원격 브랜치명을 그대로 사용한다. 임의로 브랜치명을 만들거나 변형하지 않는다.** 브랜치는 이슈 생성 후 GitHub Actions가 자동으로 생성하며, 이 워크플로우를 통해 생성된 브랜치만 사용해야 한다.

```bash
# 프로젝트 이름 추출
project=$(basename "$(git rev-parse --show-toplevel)")

# worktree 생성 (상위 디렉토리에, 이슈 번호로 폴더명 단축)
git worktree add -b <브랜치명> ../${project}-wt-issue-<이슈번호> origin/<브랜치명>
```

- 로컬에 이미 같은 이름의 브랜치가 존재하면 `-b <브랜치명>` 옵션 없이 진행한다:
  ```bash
  git worktree add ../${project}-wt-issue-<이슈번호> <브랜치명>
  ```
- 해당 경로에 이미 worktree가 존재하면, `git worktree list`로 확인 후 기존 경로를 안내한다.

완료 안내:
> "Worktree가 `../<project>-wt-issue-<이슈번호>` 경로에 생성되었습니다."
> "해당 디렉토리로 이동하여 개발을 시작하세요: `cd ../<project>-wt-issue-<이슈번호>`"
