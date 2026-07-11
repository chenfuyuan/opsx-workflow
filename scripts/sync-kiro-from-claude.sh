#!/usr/bin/env bash
#
# sync-kiro-from-claude.sh
#
# Regenerate .kiro/skills/** from .claude/commands/** and .claude/skills/**.
# Claude is the single source of truth; the Kiro skills are derived artifacts.
#
# Mapping:
#   .claude/commands/opsx/<x>.md  ->  .kiro/skills/opsx-<x>/SKILL.md  (name: opsx-<x>)
#   .claude/commands/<x>.md       ->  .kiro/skills/<x>/SKILL.md       (name: <x>)
#   .claude/skills/<x>/           ->  .kiro/skills/<x>/               (dir copied, SKILL.md rewritten)
#
# Transforms applied to every generated SKILL.md:
#   - Frontmatter is reduced to `name` (derived from the target slug) + `description`
#     (the description line is copied verbatim from the Claude source; `category`/`tags`
#     and any other Claude-only frontmatter keys are dropped).
#   - Command-namespace references `opsx:` are rewritten to `opsx-`, because Claude uses
#     the `/opsx:` slash-command namespace while Kiro uses `opsx-` skill ids.
#   - Supporting files inside a skill directory (e.g. *.sh, *.ts, extra *.md) are copied
#     unchanged.
#
# Existing Kiro skills that have no corresponding Claude source are reported but NEVER
# deleted (deletion is left to the user, to avoid destructive surprises).
#
# Usage:
#   scripts/sync-kiro-from-claude.sh            # apply changes
#   scripts/sync-kiro-from-claude.sh --dry-run  # preview only, write nothing
#
set -euo pipefail

DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --help|-h)    sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$REPO_ROOT/.claude"
KIRO_SKILLS="$REPO_ROOT/.kiro/skills"

[ -d "$CLAUDE_DIR" ] || { echo "error: $CLAUDE_DIR not found" >&2; exit 1; }

log()      { printf '%s\n' "$*"; }
fix_opsx() { sed 's/opsx:/opsx-/g'; }

# Print the (opsx-fixed) `description:` line from a file's YAML frontmatter.
desc_line() {
  awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; next} n==1 && /^description:/{print; exit}' "$1" | fix_opsx
}

# Print the body (everything after the closing frontmatter `---`), opsx-fixed.
body_after_fm() {
  awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; next} n>=2{print}' "$1" | fix_opsx
}

# render_skill <claude-source.md> <slug> <dest-dir>
render_skill() {
  src="$1"; slug="$2"; dest_dir="$3"
  dline="$(desc_line "$src")"; [ -n "$dline" ] || dline="description:"
  tmp="$(mktemp)"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$slug"
    printf '%s\n' "$dline"
    printf -- '---\n'
    body_after_fm "$src"
  } > "$tmp"
  if [ "$DRY_RUN" -eq 1 ]; then
    if [ -f "$dest_dir/SKILL.md" ] && diff -q "$dest_dir/SKILL.md" "$tmp" >/dev/null 2>&1; then
      log "  = $slug (unchanged)"
    else
      log "  ~ $slug (would write $dest_dir/SKILL.md)"
    fi
    rm -f "$tmp"
  else
    mkdir -p "$dest_dir"
    mv "$tmp" "$dest_dir/SKILL.md"
    log "  -> $slug ($dest_dir/SKILL.md)"
  fi
}

log "== commands -> kiro skills =="
while IFS= read -r f; do
  rel="${f#"$CLAUDE_DIR"/commands/}"   # opsx/archive.md | critical-review.md
  rel="${rel%.md}"                     # opsx/archive    | critical-review
  slug="$(printf '%s' "$rel" | tr '/' '-')"
  render_skill "$f" "$slug" "$KIRO_SKILLS/$slug"
done < <(find "$CLAUDE_DIR/commands" -type f -name '*.md' | sort)

log "== skills -> kiro skills =="
if [ -d "$CLAUDE_DIR/skills" ]; then
  while IFS= read -r d; do
    name="$(basename "$d")"
    dest="$KIRO_SKILLS/$name"
    # copy supporting files (everything except SKILL.md) verbatim, preserving mode
    while IFS= read -r sf; do
      srel="${sf#"$d"/}"
      if [ "$DRY_RUN" -eq 1 ]; then
        log "  copy $name/$srel"
      else
        mkdir -p "$dest/$(dirname "$srel")"
        cp -p "$sf" "$dest/$srel"
      fi
    done < <(find "$d" -type f ! -name 'SKILL.md' | sort)
    [ -f "$d/SKILL.md" ] && render_skill "$d/SKILL.md" "$name" "$dest"
  done < <(find "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 -type d | sort)
fi

log "== orphan check (kiro skills with no Claude source) =="
expected="$(
  find "$CLAUDE_DIR/commands" -type f -name '*.md' \
    | sed -e "s#$CLAUDE_DIR/commands/##" -e 's#\.md$##' -e 's#/#-#g'
  [ -d "$CLAUDE_DIR/skills" ] && find "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 -type d | sed -e 's#.*/##'
)"
orphans=0
while IFS= read -r kd; do
  kname="$(basename "$kd")"
  if ! printf '%s\n' "$expected" | grep -qx "$kname"; then
    log "  ! $kname (no Claude source; left untouched)"
    orphans=$((orphans + 1))
  fi
done < <(find "$KIRO_SKILLS" -mindepth 1 -maxdepth 1 -type d | sort)
[ "$orphans" -eq 0 ] && log "  (none)"

log "done."
