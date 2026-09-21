# herdr-file-viewer Markdown Contrast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bundled Markdown code comments and generic subheadings meet normal-text contrast requirements without adding a Dark Glass dependency.

**Architecture:** This is a palette-only bug fix in the viewer's existing trusted Glow style. A deterministic integration test reads the real JSON asset and computes WCAG contrast against its fixed code-block background. Work starts from `main`, never the unrelated `feat/global-content-search` commit.

**Tech Stack:** Rust 1.96 integration tests, `serde_json`, Glow JSON style, Cargo test/fmt/clippy/audit, protected-main GitHub PR workflow.

---

## File map

- `assets/markdown-style.json`: raise two fixed low-contrast foregrounds.
- `tests/render_delegate.rs`: parse the real asset and enforce WCAG `>= 4.5:1`.
- `docs/renderers.md`: document the terminal-relative prose palette and fixed code-block contrast floor.
- `CHANGELOG.md`: Unreleased Fixed entry.

### Task 1: Isolate the branch and prove the defect

**Files:**
- Modify: `tests/render_delegate.rs`

- [ ] **Step 1: Verify and preserve the unrelated branch**

Run:

```bash
git status --short
git log --oneline main..HEAD
```

Expected: clean worktree and exactly the unrelated `feat/global-content-search` commit. Then create the fix directly from `main`:

```bash
git switch main
git pull --ff-only origin main
git switch -c fix/markdown-code-contrast
```

Verify:

```bash
git log --oneline main..HEAD
```

Expected: no commits.

- [ ] **Step 2: Add a real-asset contrast test**

Append helpers and a test to `tests/render_delegate.rs`:

```rust
fn parse_hex_color(value: &str) -> [f64; 3] {
    let value = value.strip_prefix('#').expect("hex color starts with #");
    assert_eq!(value.len(), 6, "six-digit RGB color");
    let byte = |offset| u8::from_str_radix(&value[offset..offset + 2], 16).unwrap() as f64 / 255.0;
    [byte(0), byte(2), byte(4)]
}

fn relative_luminance(rgb: [f64; 3]) -> f64 {
    let linear = rgb.map(|value| {
        if value <= 0.04045 {
            value / 12.92
        } else {
            ((value + 0.055) / 1.055).powf(2.4)
        }
    });
    0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
}

fn contrast_ratio(left: &str, right: &str) -> f64 {
    let left = relative_luminance(parse_hex_color(left));
    let right = relative_luminance(parse_hex_color(right));
    let (bright, dark) = if left >= right { (left, right) } else { (right, left) };
    (bright + 0.05) / (dark + 0.05)
}

#[test]
fn bundled_markdown_code_text_meets_normal_text_contrast() {
    let style: serde_json::Value = serde_json::from_str(include_str!(
        "../assets/markdown-style.json"
    ))
    .expect("bundled markdown style is valid JSON");
    let chroma = &style["code_block"]["chroma"];
    let background = chroma["background"]["background_color"]
        .as_str()
        .expect("code background color");

    for key in ["comment", "generic_subheading"] {
        let foreground = chroma[key]["color"]
            .as_str()
            .unwrap_or_else(|| panic!("{key} color"));
        let ratio = contrast_ratio(foreground, background);
        assert!(
            ratio >= 4.5,
            "{key} contrast is {ratio:.2}:1, below the 4.5:1 normal-text floor"
        );
    }
}
```

- [ ] **Step 3: Run the focused test and observe RED**

```bash
cargo test --test render_delegate bundled_markdown_code_text_meets_normal_text_contrast -- --exact
```

Expected: fail showing comment around `2.10:1` (and, after that assertion is addressed or reported, generic subheading around `2.66:1`).

### Task 2: Apply the minimal palette fix

**Files:**
- Modify: `assets/markdown-style.json`
- Test: `tests/render_delegate.rs`

- [ ] **Step 1: Change only the two failing foregrounds**

```json
"comment": { "color": "#A0A0A0" },
"generic_subheading": { "color": "#A0A0A0" },
```

Keep `background.background_color` at `#373737` and every other style entry byte-for-byte unchanged.

- [ ] **Step 2: Run the focused test and observe GREEN**

```bash
cargo test --test render_delegate bundled_markdown_code_text_meets_normal_text_contrast -- --exact
```

Expected: pass; both ratios are at least `4.5:1`.

- [ ] **Step 3: Run the renderer integration suite**

```bash
cargo test --test render_delegate
```

Expected: all tests pass, including the optional real-Glow test when Glow is installed.

- [ ] **Step 4: Commit the tested palette change**

```bash
git add assets/markdown-style.json tests/render_delegate.rs
git commit -m "fix: improve Markdown code contrast" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 3: Document and verify the fix

**Files:**
- Modify: `docs/renderers.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update renderer documentation**

Append to the bundled-palette section:

```markdown
Prose colors remain terminal-relative, so the terminal profile controls headings and muted text.
The fixed code-block palette keeps comments and generic subheadings at or above a 4.5:1
contrast ratio against its bundled background.
```

- [ ] **Step 2: Add the Unreleased changelog entry**

Under `## [Unreleased]`, add a `### Fixed` section if absent:

```markdown
### Fixed
- Rendered Markdown code comments and generic subheadings no longer disappear against the bundled code-block background; both now meet a 4.5:1 contrast floor. → [renderers](docs/renderers.md#bundled-markdown-palette)
```

Do not remove the existing project-content-search entry from the base branch if it exists on `main`; confirm the branch base before editing.

- [ ] **Step 3: Run complete deterministic verification**

```bash
cargo fmt --check
cargo test
cargo clippy --all-targets -- -D warnings
cargo audit
git diff --check
git log --oneline main..HEAD
```

Expected: all commands pass; the final log contains only this fix branch's commits and never `a5c40bb feat: add project content search` unless that commit has independently landed on `main`.

- [ ] **Step 4: Commit documentation**

```bash
git add docs/renderers.md CHANGELOG.md
git commit -m "docs: note accessible Markdown code colors" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Push the configured remote branch**

```bash
git push -u origin fix/markdown-code-contrast
```

- [ ] **Step 6: Open the protected-main PR**

Create a PR against `main` with the measured root cause, the two exact palette changes, and the verification commands. End the body with:

```markdown
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Do not merge until CI is green; do not bump the release version because releases are owner-gated.
