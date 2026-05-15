#!/usr/bin/env bash
# test.sh — integration tests for setup-agents
# Usage: ./test.sh [/path/to/setup-agents]

SETUP_AGENTS="${1:-$(cd "$(dirname "$0")" && pwd)/setup-agents}"

if [[ ! -x "$SETUP_AGENTS" ]]; then
    echo "Error: cannot find executable at: $SETUP_AGENTS"
    echo "Usage: ./test.sh [/path/to/setup-agents]"
    exit 1
fi

echo "Binary : $SETUP_AGENTS"
echo "Version: $("$SETUP_AGENTS" --version 2>/dev/null || echo 'unknown')"
echo ""

# ── colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── state ─────────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; CURRENT_TEST=""
declare -a FAILURES=()

# ── assertion helpers ─────────────────────────────────────────────────────────
_ok()   { echo -e "    ${GREEN}✓${NC} $1"; ((PASS++)) || true; }
_fail() {
    echo -e "    ${RED}✗${NC} $1"
    ((FAIL++)) || true
    FAILURES+=("${CURRENT_TEST}: $1")
}

assert_exists()     { [[ -e "$1" ]]              && _ok "exists: $1"          || _fail "missing: $1"; }
assert_missing()    { [[ ! -e "$1" ]]            && _ok "absent: $1"          || _fail "should not exist: $1"; }
assert_symlink()    { [[ -L "$1" ]]              && _ok "symlink: $1"         || _fail "not a symlink: $1"; }
assert_not_symlink(){ [[ ! -L "$1" ]]            && _ok "not symlink: $1"     || _fail "is a symlink: $1"; }
assert_file()       { [[ -f "$1" && ! -L "$1" ]] && _ok "plain file: $1"     || _fail "not a plain file: $1"; }
assert_dir()        { [[ -d "$1" ]]              && _ok "dir: $1"             || _fail "missing dir: $1"; }

assert_link_target() {
    local path="$1" want="$2"
    local got; got="$(readlink "$path" 2>/dev/null || echo '')"
    [[ "$got" == "$want" ]] \
        && _ok "link target: $(basename "$path") → $want" \
        || _fail "link target: $(basename "$path") → '$got' (want '$want')"
}

assert_contains() {
    local file="$1" pat="$2"
    grep -q "$pat" "$file" 2>/dev/null \
        && _ok "contains: '$pat'" \
        || _fail "missing '$pat' in $(basename "$file")"
}

assert_exit_ok() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        _ok "exit 0: $desc"
    else
        _fail "exit non-zero: $desc"
    fi
}

assert_exit_fail() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        _fail "exit 0 (expected non-zero): $desc"
    else
        _ok "exit non-zero: $desc"
    fi
}

assert_output_contains() {
    local desc="$1" pat="$2"; shift 2
    local out; out="$("$@" 2>&1)"
    echo "$out" | grep -q "$pat" \
        && _ok "output contains '$pat': $desc" \
        || _fail "output missing '$pat': $desc"
}

# ── test runner ───────────────────────────────────────────────────────────────
run_test() {
    local name="$1"
    CURRENT_TEST="$name"
    echo -e "${CYAN}${name}${NC}"
    "$name"
}

tmp_dir() { mktemp -d; }

# ─────────────────────────────────────────────────────────────────────────────
# CLI surface
# ─────────────────────────────────────────────────────────────────────────────

test_version() {
    local out; out="$("$SETUP_AGENTS" --version 2>&1)"
    [[ "$out" == "setup-agents v"* ]] \
        && _ok "version string: $out" \
        || _fail "unexpected: $out"
}

test_help() {
    assert_exit_ok "--help exits 0" "$SETUP_AGENTS" --help
    assert_output_contains "lists init"     "init"     "$SETUP_AGENTS" --help
    assert_output_contains "lists migrate"  "migrate"  "$SETUP_AGENTS" --help
    assert_output_contains "lists status"   "status"   "$SETUP_AGENTS" --help
    assert_output_contains "lists undo"     "undo"     "$SETUP_AGENTS" --help
    assert_output_contains "lists update"   "update"   "$SETUP_AGENTS" --help
    assert_output_contains "lists templates" "templates" "$SETUP_AGENTS" --help
}

test_templates() {
    assert_output_contains "lists default" "default" "$SETUP_AGENTS" templates
    assert_output_contains "lists node"    "node"    "$SETUP_AGENTS" templates
    assert_output_contains "lists python"  "python"  "$SETUP_AGENTS" templates
}

test_error_unknown_flag() {
    assert_exit_fail "unknown flag fails" "$SETUP_AGENTS" --notaflag
}

test_error_bad_template() {
    local d; d="$(tmp_dir)"
    assert_exit_fail "unknown template fails" "$SETUP_AGENTS" init "$d" --template nonexistent
    rm -rf "$d"
}

# ─────────────────────────────────────────────────────────────────────────────
# init
# ─────────────────────────────────────────────────────────────────────────────

test_init_default() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1

    assert_dir     "$d/.agents"
    assert_file    "$d/AGENTS.md"
    assert_file    "$d/.agents/mcps.md"
    assert_file    "$d/.agents/pending-work.md"
    assert_symlink "$d/.claude/CLAUDE.md"
    assert_link_target "$d/.claude/CLAUDE.md" "../AGENTS.md"

    assert_contains "$d/AGENTS.md"               "## Session protocol"
    assert_contains "$d/AGENTS.md"               "## NEVER DO"
    assert_contains "$d/AGENTS.md"               "## ALWAYS DO"
    assert_contains "$d/AGENTS.md"               "## ASK FIRST"
    assert_contains "$d/AGENTS.md"               "pending-work.md"
    assert_contains "$d/.agents/mcps.md"         "## Configured servers"
    assert_contains "$d/.agents/pending-work.md" "## How to use"
    assert_contains "$d/.agents/pending-work.md" "## Pending"
    assert_contains "$d/.agents/pending-work.md" "## Changelog"

    rm -rf "$d"
}

test_init_template_node() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" --template node >/dev/null 2>&1

    assert_contains "$d/AGENTS.md" "npm run dev"
    assert_contains "$d/AGENTS.md" "npm test"
    assert_contains "$d/AGENTS.md" "TypeScript strict mode"

    rm -rf "$d"
}

test_init_template_python() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" --template python >/dev/null 2>&1

    assert_contains "$d/AGENTS.md" "ruff check"
    assert_contains "$d/AGENTS.md" "pytest"
    assert_contains "$d/AGENTS.md" "mypy"

    rm -rf "$d"
}

test_init_all() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" --all >/dev/null 2>&1

    assert_symlink "$d/.cursorrules"
    assert_link_target "$d/.cursorrules" "AGENTS.md"
    assert_symlink "$d/.windsurfrules"
    assert_link_target "$d/.windsurfrules" "AGENTS.md"
    assert_symlink "$d/.github/copilot-instructions.md"
    assert_link_target "$d/.github/copilot-instructions.md" "../AGENTS.md"
    assert_symlink "$d/.zed/rules.md"
    assert_link_target "$d/.zed/rules.md" "../AGENTS.md"

    rm -rf "$d"
}

test_init_idempotent() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    assert_exit_ok "second init exits 0" "$SETUP_AGENTS" init "$d"

    # state intact after second run
    assert_symlink "$d/.claude/CLAUDE.md"
    assert_file    "$d/AGENTS.md"
    assert_file    "$d/.agents/mcps.md"
    assert_file    "$d/.agents/pending-work.md"

    rm -rf "$d"
}

test_init_from_existing_claude_md() {
    local d; d="$(tmp_dir)"
    mkdir -p "$d/.claude"
    echo "# My existing instructions" > "$d/.claude/CLAUDE.md"
    echo "# Reference doc"            > "$d/.claude/reference.md"

    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1

    assert_file    "$d/AGENTS.md"
    assert_contains "$d/AGENTS.md" "My existing instructions"   # copied from CLAUDE.md
    assert_file    "$d/.agents/reference.md"                    # moved from .claude/
    assert_missing "$d/.claude/reference.md"                    # gone from .claude/
    assert_symlink "$d/.claude/CLAUDE.md"
    assert_link_target "$d/.claude/CLAUDE.md" "../AGENTS.md"

    rm -rf "$d"
}

test_init_gitignore_tip() {
    local d; d="$(tmp_dir)"
    local out; out="$("$SETUP_AGENTS" init "$d" 2>&1)"

    echo "$out" | grep -q "\.local\.md" \
        && _ok "shows .gitignore tip" \
        || _fail "missing .gitignore tip in output"

    rm -rf "$d"
}

# ─────────────────────────────────────────────────────────────────────────────
# add
# ─────────────────────────────────────────────────────────────────────────────

test_add_cursor() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    (cd "$d" && "$SETUP_AGENTS" add cursor) >/dev/null 2>&1

    assert_symlink "$d/.cursorrules"
    assert_link_target "$d/.cursorrules" "AGENTS.md"

    rm -rf "$d"
}

test_add_windsurf() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    (cd "$d" && "$SETUP_AGENTS" add windsurf) >/dev/null 2>&1

    assert_symlink "$d/.windsurfrules"
    assert_link_target "$d/.windsurfrules" "AGENTS.md"

    rm -rf "$d"
}

test_add_copilot() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    (cd "$d" && "$SETUP_AGENTS" add copilot) >/dev/null 2>&1

    assert_symlink "$d/.github/copilot-instructions.md"
    assert_link_target "$d/.github/copilot-instructions.md" "../AGENTS.md"

    rm -rf "$d"
}

test_add_zed() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    (cd "$d" && "$SETUP_AGENTS" add zed) >/dev/null 2>&1

    assert_symlink "$d/.zed/rules.md"
    assert_link_target "$d/.zed/rules.md" "../AGENTS.md"

    rm -rf "$d"
}

test_add_all_standalone() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    (cd "$d" && "$SETUP_AGENTS" add --all) >/dev/null 2>&1

    assert_symlink "$d/.cursorrules"
    assert_symlink "$d/.windsurfrules"
    assert_symlink "$d/.github/copilot-instructions.md"
    assert_symlink "$d/.zed/rules.md"

    rm -rf "$d"
}

test_add_idempotent() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    (cd "$d" && "$SETUP_AGENTS" add cursor) >/dev/null 2>&1
    assert_exit_ok "add cursor twice exits 0" bash -c "cd '$d' && '$SETUP_AGENTS' add cursor"
    assert_symlink "$d/.cursorrules"   # still symlink, not corrupted

    rm -rf "$d"
}

test_error_bad_adapter() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    assert_exit_fail "unknown adapter fails" bash -c "cd '$d' && '$SETUP_AGENTS' add vscode"
    rm -rf "$d"
}

test_error_add_without_init() {
    local d; d="$(tmp_dir)"
    assert_exit_fail "add without AGENTS.md fails" bash -c "cd '$d' && '$SETUP_AGENTS' add cursor"
    rm -rf "$d"
}

# ─────────────────────────────────────────────────────────────────────────────
# status
# ─────────────────────────────────────────────────────────────────────────────

test_status_clean() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" --all >/dev/null 2>&1
    assert_exit_ok "status exits 0 on clean setup" "$SETUP_AGENTS" status "$d"

    assert_output_contains "reports all checks passed" "All checks passed" \
        "$SETUP_AGENTS" status "$d"

    rm -rf "$d"
}

test_status_detects_plain_claude_md() {
    local d; d="$(tmp_dir)"
    mkdir -p "$d/.claude"
    echo "# test" > "$d/.claude/CLAUDE.md"   # plain file, not symlink

    local out; out="$("$SETUP_AGENTS" status "$d" 2>&1)"
    echo "$out" | grep -qi "plain file\|missing\|not found" \
        && _ok "status reports issue with plain CLAUDE.md" \
        || _fail "status missed plain CLAUDE.md issue"

    rm -rf "$d"
}

test_status_validates_sections() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1

    # remove a required section
    sed -i.bak '/^## NEVER DO/d' "$d/AGENTS.md"

    local out; out="$("$SETUP_AGENTS" status "$d" 2>&1)"
    echo "$out" | grep -q "NEVER DO" \
        && _ok "status detects missing section" \
        || _fail "status missed missing section"

    rm -rf "$d"
}

# ─────────────────────────────────────────────────────────────────────────────
# migrate
# ─────────────────────────────────────────────────────────────────────────────

test_migrate_dry_run() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    mkdir -p "$d/.claude/specs"
    echo "# spec" > "$d/.claude/specs/api.md"

    "$SETUP_AGENTS" migrate "$d" --dry-run >/dev/null 2>&1

    assert_dir    "$d/.claude/specs"   # not moved
    assert_missing "$d/.agents/specs"  # not created

    rm -rf "$d"
}

test_migrate_yes_specs() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    mkdir -p "$d/.claude/specs"
    echo "# spec" > "$d/.claude/specs/api.md"

    "$SETUP_AGENTS" migrate "$d" --yes >/dev/null 2>&1

    assert_dir     "$d/.agents/specs"    # moved
    assert_symlink "$d/.claude/specs"    # symlink left behind
    assert_link_target "$d/.claude/specs" "../.agents/specs"

    rm -rf "$d"
}

test_migrate_yes_commands_stay() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    mkdir -p "$d/.claude/commands"
    echo "# cmd" > "$d/.claude/commands/deploy.md"

    "$SETUP_AGENTS" migrate "$d" --yes >/dev/null 2>&1

    # default for commands = leave in place
    assert_dir         "$d/.claude/commands"
    assert_not_symlink "$d/.claude/commands"
    assert_missing     "$d/.agents/commands"

    rm -rf "$d"
}

test_migrate_dry_run_no_changes() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    mkdir -p "$d/.claude/specs"

    local out; out="$("$SETUP_AGENTS" migrate "$d" --dry-run 2>&1)"
    echo "$out" | grep -qi "dry.run\|no changes" \
        && _ok "dry-run output mentions no changes" \
        || _fail "dry-run output unclear"

    rm -rf "$d"
}

test_error_migrate_no_claude_dir() {
    local d; d="$(tmp_dir)"
    assert_exit_fail "migrate without .claude/ fails" "$SETUP_AGENTS" migrate "$d"
    rm -rf "$d"
}

# ─────────────────────────────────────────────────────────────────────────────
# undo
# ─────────────────────────────────────────────────────────────────────────────

test_undo_restores_claude_md() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    "$SETUP_AGENTS" undo "$d" >/dev/null 2>&1

    assert_file        "$d/.claude/CLAUDE.md"   # restored as plain file
    assert_not_symlink "$d/.claude/CLAUDE.md"
    assert_contains    "$d/.claude/CLAUDE.md" "Session protocol"  # content from AGENTS.md
    assert_file        "$d/AGENTS.md"           # left in place

    rm -rf "$d"
}

test_undo_removes_adapter_symlinks() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" --all >/dev/null 2>&1
    "$SETUP_AGENTS" undo "$d" >/dev/null 2>&1

    assert_missing "$d/.cursorrules"
    assert_missing "$d/.windsurfrules"
    assert_missing "$d/.github/copilot-instructions.md"
    assert_missing "$d/.zed/rules.md"
    assert_file    "$d/AGENTS.md"    # never removed

    rm -rf "$d"
}

test_undo_idempotent() {
    local d; d="$(tmp_dir)"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1
    "$SETUP_AGENTS" undo "$d" >/dev/null 2>&1
    assert_exit_ok "undo twice exits 0" "$SETUP_AGENTS" undo "$d"

    rm -rf "$d"
}

# ─────────────────────────────────────────────────────────────────────────────
# pending-work.md content
# ─────────────────────────────────────────────────────────────────────────────

test_pending_work_has_project_name() {
    local d; d="$(tmp_dir)"
    local name; name="$(basename "$d")"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1

    assert_contains "$d/.agents/pending-work.md" "$name"

    rm -rf "$d"
}

test_pending_work_has_today() {
    local d; d="$(tmp_dir)"
    local today; today="$(date '+%d %b %Y')"
    "$SETUP_AGENTS" init "$d" >/dev/null 2>&1

    assert_contains "$d/.agents/pending-work.md" "$today"

    rm -rf "$d"
}

# ─────────────────────────────────────────────────────────────────────────────
# RUN ALL TESTS
# ─────────────────────────────────────────────────────────────────────────────

TESTS=(
    # CLI surface
    test_version
    test_help
    test_templates
    test_error_unknown_flag
    test_error_bad_template

    # init
    test_init_default
    test_init_template_node
    test_init_template_python
    test_init_all
    test_init_idempotent
    test_init_from_existing_claude_md
    test_init_gitignore_tip

    # add
    test_add_cursor
    test_add_windsurf
    test_add_copilot
    test_add_zed
    test_add_all_standalone
    test_add_idempotent
    test_error_bad_adapter
    test_error_add_without_init

    # status
    test_status_clean
    test_status_detects_plain_claude_md
    test_status_validates_sections

    # migrate
    test_migrate_dry_run
    test_migrate_yes_specs
    test_migrate_yes_commands_stay
    test_migrate_dry_run_no_changes
    test_error_migrate_no_claude_dir

    # undo
    test_undo_restores_claude_md
    test_undo_removes_adapter_symlinks
    test_undo_idempotent

    # pending-work
    test_pending_work_has_project_name
    test_pending_work_has_today
)

for t in "${TESTS[@]}"; do
    run_test "$t"
    echo ""
done

# ── summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "────────────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All ${TOTAL} assertions passed.${NC}"
else
    echo -e "${RED}${BOLD}${FAIL} failed · ${PASS} passed · ${TOTAL} total${NC}"
    echo ""
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
        echo -e "  ${RED}✗${NC} $f"
    done
fi
echo ""

[[ $FAIL -eq 0 ]]
