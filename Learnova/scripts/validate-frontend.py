#!/usr/bin/env python3
"""Static validation for the Learnova frontend.

Checks that:
  1. Every <script src> referenced by an HTML page exists on disk.
  2. Every page loads the core auth scripts (constants, session, routeGuard).
  3. Lesson content block types match the database CHECK constraint (LTC13):
     markdown, youtube, pdf, link, image, code.
  4. Reports which pages still load the offline mock adapter (mock.js).

Usage:
    python scripts/validate-frontend.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FRONTEND = ROOT / "frontend"

ALLOWED_BLOCK_TYPES = {"markdown", "youtube", "pdf", "link", "image", "code"}

CORE_SCRIPTS = ("js/utils/constants.js", "js/auth/session.js", "js/auth/routeGuard.js")

SCRIPT_SRC_RE = re.compile(r"<script\s+[^>]*src=\"([^\"]+)\"")
BLOCK_TYPE_VALUES_RE = re.compile(r"value:\s*'([a-z]+)'\s*,\s*label:")
BLOCK_TYPE_KEYS_RE = re.compile(r"([a-z]+):\s*'(?:Video|Article|Notes|PDF)'")

MOCK_ROUTES = ("quiz-editor", "prerequisite-editor", "progress", "certificates")


def html_files():
    return sorted(FRONTEND.rglob("*.html"))


def resolve(path, base):
    target = (base.parent / path).resolve()
    return target


def check_script_srcs():
    issues = []
    total_scripts = 0
    mock_pages = []
    for html in html_files():
        text = html.read_text(encoding="utf-8", errors="replace")
        refs = SCRIPT_SRC_RE.findall(text)
        missing = []
        for ref in refs:
            if ref.startswith(("http://", "https://", "//")):
                continue
            total_scripts += 1
            if not resolve(ref, html).is_file():
                missing.append(ref)
        if missing:
            issues.append(f"{html.relative_to(FRONTEND)}: missing script {', '.join(missing)}")
        if "js/api/mock.js" in text:
            mock_pages.append(str(html.relative_to(FRONTEND)))
    return issues, total_scripts, mock_pages


def check_core_scripts():
    issues = []
    for html in html_files():
        if html.name == "index.html":
            continue
        text = html.read_text(encoding="utf-8", errors="replace")
        missing = [core for core in CORE_SCRIPTS if core not in text]
        if missing:
            issues.append(f"{html.relative_to(FRONTEND)}: missing core script {', '.join(missing)}")
    return issues


def check_block_types():
    issues = []
    targets = [
        FRONTEND / "js/pages/instructor/lessonEditor.js",
        FRONTEND / "js/pages/student/lessonView.js",
        FRONTEND / "js/api/mock.js",
    ]
    for path in targets:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        found = set()
        found.update(BLOCK_TYPE_VALUES_RE.findall(text))
        found.update(BLOCK_TYPE_KEYS_RE.findall(text))
        bad = sorted(found - ALLOWED_BLOCK_TYPES)
        if bad:
            rel = path.relative_to(FRONTEND)
            issues.append(f"{rel}: block types not allowed by DB CHECK (LTC13): {', '.join(bad)}")
    return issues


def main():
    exit_code = 0
    script_issues, total_scripts, mock_pages = check_script_srcs()
    core_issues = check_core_scripts()
    block_issues = check_block_types()

    print("=" * 60)
    print("Learnova frontend validation")
    print("=" * 60)
    print(f"HTML pages checked : {len(html_files())}")
    print(f"Local <script> refs: {total_scripts}")
    print(f"Pages loading mock.js: {len(mock_pages)}")
    for page in mock_pages:
        print(f"  - {page}")

    if mock_pages:
        print(f"  NOTE: these pages still use the offline mock adapter; "
              f"{'/'.join(MOCK_ROUTES)} are not backed by real endpoints.")

    for label, issues in (
        ("Missing script sources", script_issues),
        ("Missing core scripts", core_issues),
        ("Invalid block types", block_issues),
    ):
        print(f"\n[{label}] {len(issues)} issue(s)")
        for issue in issues:
            print(f"  ! {issue}")
        if issues:
            exit_code = 1

    print("\n" + ("PASS" if exit_code == 0 else "FAIL"))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
