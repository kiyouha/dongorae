# dongorae

돈고래 — 개인 자산관리 서버(거래·자산·가계부 + 주식시세·거시경제·부동산 + 자동매매(KIS)).
**이 맥(`~/Server/dongorae`)에서 docker compose로 직접 운영한다.** (예전 NAS/goraes 모노레포 운영은 종료)

```text
dongorae/
├── app/                  # 돈고래 FastAPI 앱 (+ app/static/ SPA)
├── cli.py  Dockerfile  entrypoint.sh  cron_entrypoint.sh  crontab
├── data/                 # 거래내역 inbox·symbols·로그 (컨테이너와 공유)
├── files/                # 사용자 공유폴더(거래내역 import/export·문서). NAS /volume2/goraes 자리
├── auth-server/          # 인증 서버 (네이버 로그인, 가족 승인제)
├── gateway/nginx.conf    # 단일 진입 nginx (:8000) — 로그인 게이팅
├── pgadmin/              # DB 뷰어 설정
├── shared/base.css       # 공통 디자인 토큰 (게이트웨이가 /shared/ 로 서빙)
├── docker-compose.yml    # 단일 스택: don-db/app/scheduler + auth-db/app + gateway (+pgadmin)
└── manage.sh             # 기동·로그·재빌드·백업 래퍼
```

**접속은 `http://localhost:8000`** (gateway) → 네이버 로그인 → 돈고래(`/don/`).
게이트웨이가 한 origin으로 세션을 공유하고 nginx `auth_request`로 `/don/`을 로그인 뒤로 보호한다.
DB는 서비스별로 분리(`don-net`/`auth-net`), 앱 계층만 `dongorae-net`으로 붙어 gateway → auth/don 호출이 된다.
**첫 로그인 사용자가 자동으로 관리자**가 되고, 이후 가입자는 관리자 승인(`/admin`)이 필요하다.

빠른 시작:

```bash
cp .env.example .env      # 이미 채워져 있으면 생략 (네이버 키·MOLIT 키)
./manage.sh start         # 빌드 + 기동
open http://localhost:8000
```

> 이력: 2026-07-16 부동산/시장데이터를 별도 서비스로 나눴다가 **dongorae 단일 앱으로 재통합**,
> 2026-07-30 `rakgorae`(자동매매)도 dongorae 모듈(KIS)로 통합.
> 2026-08-29 **NAS(goraes 모노레포) 운영을 접고 이 맥의 dongorae 단독 저장소로 이관**
> (docgorae·clients는 가져오지 않음). 자세히는 `.ai/DECISIONS.md`.

---

# Claude Code Minimal-Context Development Template

This template is designed for one goal:

> Continue long-running development work across Claude Code sessions
> while minimizing token usage.

The structure keeps always-loaded instructions small and loads domain
knowledge only when needed.

## 1. Directory Structure

``` text
project/
├── CLAUDE.md
├── README.md
├── .claude/
│   ├── skills/
│   │   ├── continue/
│   │   │   └── SKILL.md
│   │   ├── handoff/
│   │   │   └── SKILL.md
│   │   ├── jira-pipeline/
│   │   │   └── SKILL.md
│   │   ├── gerrit-analysis/
│   │   │   └── SKILL.md
│   │   ├── sqm/
│   │   │   └── SKILL.md
│   │   └── architecture-change/
│   │       └── SKILL.md
│   └── agents/
│       └── explorer.md
├── .ai/
│   ├── CURRENT.md
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md
│   └── ROADMAP.md
└── scripts/
    ├── ai-status.sh
    └── test-changed.sh
```

## 2. Installation

Copy the template contents into the root of your existing Git project.

Example:

``` bash
cp -R claude_min_context_template/. /path/to/your/project/
cd /path/to/your/project
chmod +x scripts/*.sh
```

Do not blindly overwrite an existing `CLAUDE.md` or `.claude/`
directory. Merge existing project rules and skills if they already
exist.

After copying, edit these files first:

1.  `CLAUDE.md` --- add only permanent, project-wide constraints.
2.  `.ai/ARCHITECTURE.md` --- write a short stable architecture summary.
3.  `.ai/ROADMAP.md` --- list major milestones only.
4.  `.ai/CURRENT.md` --- describe the current unfinished task, or clear
    the example content.

## 3. Daily Workflow

### Start a new session

Run the `continue` skill:

``` text
/continue
```

Expected behavior:

1.  Read `.ai/CURRENT.md`.
2.  Check `git status --short`.
3.  Check `git diff --stat`.
4.  Compare repository state with the saved handoff.
5.  Read only active files and directly related dependencies.
6.  Continue from `Next action`.

The purpose is to avoid rereading the entire repository or replaying
previous chat history.

### During development

Ask Claude to work normally, but keep tasks narrow.

Good:

``` text
Implement the next action from CURRENT.md.
Use the jira-pipeline skill.
Do not inspect unrelated modules.
Run focused tests only.
```

Avoid:

``` text
Read the entire project and understand everything before continuing.
```

For large repository exploration, use the Explorer agent only when the
result can be returned as a compact summary. Do not use multiple agents
by default because repeated repository exploration increases token
usage.

### Before ending a session

Run:

``` text
/handoff
```

The handoff skill updates `.ai/CURRENT.md` with:

-   goal
-   current status
-   completed facts
-   unresolved problem
-   one concrete next action
-   active files
-   validation status
-   important non-obvious context
-   Git state

The handoff file should contain state, not conversation history.

Commit the handoff together with code when appropriate so another
machine or developer can continue from the same state.

## 4. What Each File Is For

### `CLAUDE.md`

Always-loaded project rules.

Put only information that must apply to almost every task:

-   runtime compatibility requirements
-   forbidden changes
-   test policy
-   minimal-change policy
-   context-loading rules

Do not put detailed architecture, Jira field mappings, database schemas,
or long workflows here.

### `.ai/CURRENT.md`

Short-lived task state.

Update it when:

-   stopping unfinished work
-   changing the active task
-   discovering a blocker
-   finishing a meaningful implementation step

Keep it compact. The next session should be able to continue by reading
this file plus Git state.

### `.ai/ARCHITECTURE.md`

Stable system structure.

Examples:

-   major services
-   ownership boundaries
-   high-level data flow
-   important persistence layers
-   external integrations

Do not update it for every small code change.

### `.ai/DECISIONS.md`

Durable architecture and design decisions.

Recommended format:

``` text
## YYYY-MM-DD — Decision title

Context:
Short reason the decision was needed.

Decision:
What was chosen.

Reason:
Why this option was selected.

Consequences:
Important trade-offs or constraints.
```

Use this file to prevent future sessions from reopening already-settled
design questions.

### `.ai/ROADMAP.md`

Major milestones only.

Good:

``` text
1. Jira raw ingestion
2. Requirement normalization
3. TC mapping
4. Gerrit mirror and patchset analysis
5. SQM aggregation
```

Avoid detailed TODO lists here. Detailed active work belongs in
`CURRENT.md`.

## 5. Skills

### `/continue`

Use at the start of a new session or after context loss.

Purpose: recover the current task with minimal context.

### `/handoff`

Use before stopping unfinished work.

Purpose: save a compact continuation state.

### `jira-pipeline`

Use for Jira issue collection, raw storage, normalization, requirement
parsing, and TC relation processing.

### `gerrit-analysis`

Use for Gerrit repositories, branches, commits, patchsets, changed-file
analysis, effective LoC calculation, and module mapping.

### `sqm`

Use for SQM collection, metric normalization, aggregation, and
traceability.

### `architecture-change`

Use only for changes that alter service boundaries, data ownership,
pipeline stages, schemas, or cross-module architecture.

Do not activate architecture work for ordinary bug fixes.

## 6. Explorer Agent

The Explorer agent is for repository investigation that would otherwise
fill the main context with temporary information.

Good use cases:

-   locate the implementation path for one feature
-   identify callers and dependencies
-   find the source of a specific field
-   summarize a narrow data flow

Bad use cases:

-   read the entire repository
-   produce a full architecture report for every task
-   run multiple explorers over overlapping areas

Ask for a compact result such as:

``` text
Find the Jira requirement ingestion path.
Return only:
- entry point
- call chain
- persistence model
- tests
- maximum 10 relevant files
```

## 7. Scripts

### `scripts/ai-status.sh`

Use to get a compact repository state before continuing work.

``` bash
./scripts/ai-status.sh
```

The script is intended to provide small Git-oriented status output
instead of making Claude inspect many files.

### `scripts/test-changed.sh`

Use as a starting point for targeted validation.

``` bash
./scripts/test-changed.sh
```

Customize this script for the actual project stack. For example:

-   Django: targeted `pytest` paths or `manage.py check`
-   Java: module-specific Gradle tests
-   Node.js: changed-package tests
-   C/C++: affected target tests

The script should summarize failures and avoid printing huge successful
logs.

## 8. Token-Saving Rules

Use these rules consistently:

1.  Keep `CLAUDE.md` small.
2.  Load only the Skill relevant to the current task.
3.  Search before reading large files.
4.  Read functions or narrow ranges before whole files.
5.  Prefer one main Claude session.
6.  Use Explorer only for high-noise investigation.
7.  Avoid multiple agents reading the same repository area.
8.  Run targeted tests before full test suites.
9.  Filter large logs before giving them to Claude.
10. Save task state in `CURRENT.md`, not chat history.
11. Save durable reasoning in `DECISIONS.md`.
12. Let Git preserve code state; do not duplicate code in handoff notes.

## 9. Recommended Language Policy

Use English for:

-   `CLAUDE.md`
-   Skill instructions
-   agent instructions
-   architecture headings
-   workflow commands

Keep source business data in its original language:

-   Jira issue text
-   requirement descriptions
-   TC descriptions
-   Korean domain terminology that loses meaning when translated

English is not automatically cheaper in every case. The larger benefit
is that concise English instructions align well with code, CLI commands,
identifiers, and technical terminology. Structure and brevity matter
more than translating every sentence.

## 10. Example Session

Session 1:

``` text
/continue

Implement the next action.
Use jira-pipeline.
Keep raw ingestion and normalization separate.
Run focused tests only.
```

Before stopping:

``` text
/handoff
```

Session 2:

``` text
/continue
```

Claude should recover the goal, current problem, active files,
validation state, and next action without needing the previous chat.

## 11. Recommended Operating Model

For token-constrained development, use:

``` text
Main Claude
  |
  +-- CLAUDE.md: small permanent rules
  |
  +-- Skill: one task-specific workflow
  |
  +-- CURRENT.md: compact continuation state
  |
  +-- Git: code and diff state
  |
  +-- Explorer: only when investigation would pollute context
  |
  +-- scripts: deterministic status and validation
```

Start simple. Add new Skills only when a workflow repeats often enough
to justify maintaining one.
