# Protocol K

흩어진 공공 API를 MCP(Model Context Protocol)로 일원화하는 인프라 플랫폼.

> 2026 국가 AI 경진대회 출품 프로젝트

---

## What is it

한국 공공 Open API(data.go.kr 등 10만+ 데이터셋)는 명세·인증·응답 포맷이 제각각이라 LLM 에이전트가 활용하기 어렵다. Protocol K는 이를 **단일 MCP 인터페이스**로 정규화하고, 변환된 도구를 **검색·발견 가능한 카탈로그**로 제공한다.

**Phase 1 범위**: 변환(MCP-ify) + 검색. 에이전트·워크플로 자동화는 그 다음 단계.

자세한 기획은 `index.html` (브라우저에서 열기) 참조.

---

## 빠른 시작

```bash
# 레포 클론
gh repo clone WontaeKim89/protocol_k
cd protocol_k

# 기획 페이지 열기
open index.html
```

---

## 문서

| 문서 | 내용 |
|---|---|
| [`index.html`](./index.html) | 기획 페이지 (전체 비전·일정·KPI·로드맵) |
| [`docs/proposal/architecture.html`](./docs/proposal/architecture.html) | 개발 아키텍처·프레임워크 제안서 (동료 대상) |
| [`docs/proposal/conventions.html`](./docs/proposal/conventions.html) | 개발 컨벤션 (이슈·브랜치·PR·리뷰·머지) |
| [`docs/setup/sprint-setup.md`](./docs/setup/sprint-setup.md) | GitHub Project + Sprint 자동 배정 셋업 가이드 |

---

## 개발 워크플로

이 레포는 **이슈 퍼스트** 워크플로를 따른다. 모든 작업은 GitHub Issue 생성 → 자동 브랜치 생성으로 시작한다.

### 한 줄 명령어

Claude Code 또는 Codex CLI에서:

> "이슈 생성해줘 — XX 기능"

이 한 줄이 다음을 자동으로 수행한다.

1. GitHub Issue 생성 (이슈 템플릿 적용)
2. 현재 Sprint에 자동 배정 (GitHub Project)
3. GitHub Actions가 본문 파싱 → 브랜치 자동 생성 (`feature/<slug>-issue`)
4. (선택) 로컬에 worktree로 즉시 체크아웃

### 스킬 위치

| 도구 | 경로 |
|---|---|
| Claude Code | `.claude/skills/create-issue/SKILL.md` |
| Codex CLI | `.codex/skills/create-issue/SKILL.md` |

스크립트는 공유: `.claude/skills/create-issue/scripts/`

### 브랜치 명명 규칙

| Prefix | 용도 |
|---|---|
| `feature/<slug>-issue` | 신규 기능 |
| `fix/<slug>-issue` | 일반 버그 |
| `hotfix/<slug>-issue` | 운영 긴급 |
| `chore/<slug>-issue` | 리팩토링·문서 |

이름 충돌 시 `-01-issue`, `-02-issue` 순번 자동 부여.

### PR 정책 요약

| 작업자 | 리뷰어 | 머지 |
|---|---|---|
| FE (조현재) | 없음 (셀프 머지) | 본인 |
| BE / 그 외 | 2명 (1명 등록 + 1명 @멘션) · 1명 이상 Approve | 본인 |

자세한 내용은 [`docs/proposal/conventions.html`](./docs/proposal/conventions.html) 참조.

---

## 기술 스택 (제안)

| 영역 | 선택 |
|---|---|
| Repo 전략 | 모노레포 |
| Backend | FastAPI + FastMCP |
| Backend 패키지 | uv |
| Frontend | React + Vite (pnpm) |
| DB | PostgreSQL + pgvector |
| 배포 | GitHub Actions → Azure Container Apps / GitHub Pages |

상세: [`docs/proposal/architecture.html`](./docs/proposal/architecture.html)

---

## 라이선스

미정 (Phase 1 종료 시 결정).
