#!/usr/bin/env python3
"""Render REVIEW.md / TRIAGE.md into a self-contained HTML file next to it.

The MD file is the single source of truth; the HTML is a derived view and is
always regenerated in full. Stdlib only, so it runs on the host and inside the
claude-sandbox container alike.

Usage: render.py REVIEW.md [OUT.html]   (default: same name with .html)
"""

import html
import re
import sys
from pathlib import Path

CSS = """
:root { --bg:#fff; --fg:#1f2328; --muted:#59636e; --border:#d1d9e0; --code-bg:#f6f8fa;
  --link:#0969da; --red:#cf222e; --amber:#9a6700; --green:#1a7f37; --blue:#0969da; --gray:#59636e; }
@media (prefers-color-scheme: dark) { :root { --bg:#0d1117; --fg:#e6edf3; --muted:#9198a1;
  --border:#3d444d; --code-bg:#151b23; --link:#4493f8; --red:#f85149; --amber:#d29922;
  --green:#3fb950; --blue:#4493f8; --gray:#9198a1; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg);
  font:16px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif; }
main { max-width:52rem; margin:0 auto; padding:2rem 1rem 4rem; }
h1 { font-size:1.6rem; margin:0 0 .25rem; line-height:1.3; }
h2 { font-size:1.25rem; margin:2.25rem 0 .75rem; padding-bottom:.3rem; border-bottom:1px solid var(--border); }
h3 { font-size:1.05rem; margin:1.5rem 0 .5rem; }
h4 { font-size:1rem; margin:1.25rem 0 .5rem; }
a { color:var(--link); }
code, pre { font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:.875em; }
code { background:var(--code-bg); padding:.1em .35em; border-radius:4px; }
pre { background:var(--code-bg); padding:.75rem 1rem; border-radius:6px; overflow-x:auto; line-height:1.45; }
pre code { background:none; padding:0; }
blockquote { margin:0; padding:0 1rem; color:var(--muted); border-left:3px solid var(--border); }
ul, ol { padding-left:1.5rem; }
.meta { color:var(--muted); font-size:.9rem; margin:.25rem 0 1rem; }
.meta code { font-size:.85em; }
.badges { display:flex; flex-wrap:wrap; gap:.5rem; margin:.75rem 0; }
.badge, .tag { display:inline-block; border:1px solid currentColor; border-radius:999px;
  padding:.05rem .6rem; font-size:.8rem; font-weight:600; white-space:nowrap; }
.tag { margin-right:.4rem; vertical-align:.1em; }
.c-red { color:var(--red); } .c-amber { color:var(--amber); } .c-green { color:var(--green); }
.c-blue { color:var(--blue); } .c-gray { color:var(--gray); }
details { margin:1rem 0; } summary { cursor:pointer; color:var(--muted); font-size:.9rem; }
"""

# Severity / finding tags and verdict-like values -> color class.
COLORS = {
    "blocking": "red", "do-not-merge": "red", "request-changes": "red", "wontfix": "red",
    "should-fix": "amber", "hold": "amber", "needs-discussion": "amber", "needs-info": "amber",
    "cause": "amber",
    "approve": "green", "merge": "green", "accepted": "green", "resolved": "green",
    "question": "blue", "related-issue": "blue", "related-pr": "blue", "related-code": "blue",
    "reproducibility": "blue",
}


def color(token):
    return "c-" + COLORS.get(token.strip().lower(), "gray")


def split_frontmatter(text):
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return text[4:end], text[end + 5:]
    return "", text


def parse_frontmatter(fm):
    """Top-level `key: value` scalars, plus `decision:` inside a `gate:` block."""
    scalars, nested, block = {}, False, None
    for line in fm.splitlines():
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            block = key
            if val:
                scalars[key] = val.strip('"').strip("'")
            else:
                nested = True
        elif line.strip():
            nested = True
            g = re.match(r"^\s+decision:\s*(\S+)", line)
            if block == "gate" and g:
                scalars["gate.decision"] = g.group(1)
    return scalars, nested


def inline(s):
    # Swap code spans for placeholders so emphasis/links can wrap around them.
    codes = []

    def stash(m):
        codes.append("<code>%s</code>" % html.escape(m.group(1)))
        return "\x00%d\x00" % (len(codes) - 1)

    p = html.escape(re.sub(r"`([^`]*)`", stash, s), quote=False)
    p = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2">\1</a>', p)
    p = re.sub(r"(?<![\w\"=/])(https?://[^\s<\x00]+[^\s<\x00.,;:)])", r'<a href="\1">\1</a>', p)
    p = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", p)
    p = re.sub(r"(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])", r"<em>\1</em>", p)
    return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], p)


def heading(level, text):
    m = re.match(r"^\[([\w-]+)\]\s*(.*)$", text)
    if m:
        tag = m.group(1)
        return '<h%d><span class="tag %s">%s</span>%s</h%d>' % (
            level, color(tag), html.escape(tag), inline(m.group(2)), level)
    return "<h%d>%s</h%d>" % (level, inline(text), level)


def render_body(md):
    lines = md.splitlines()
    out, para, stack = [], [], []  # stack: (indent, "ul"|"ol") of open lists

    def flush_para():
        if para:
            out.append("<p>%s</p>" % inline(" ".join(para)))
            para.clear()

    def close_lists(to_indent=-1):
        while stack and stack[-1][0] > to_indent:
            out.append("</li></%s>" % stack.pop()[1])

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        indent = len(line) - len(line.lstrip(" "))

        fence = re.match(r"^\s*(```+|~~~+)", line)
        if fence:
            flush_para()
            mark, code = fence.group(1), []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith(mark):
                code.append(lines[i][indent:] if lines[i][:indent].isspace() else lines[i])
                i += 1
            out.append("<pre><code>%s</code></pre>" % html.escape("\n".join(code)))
            i += 1
            continue

        if not stripped:
            flush_para()
            i += 1
            continue

        h = re.match(r"^(#{1,4})\s+(.*)$", line)
        if h:
            flush_para()
            close_lists()
            out.append(heading(len(h.group(1)), h.group(2).strip()))
            i += 1
            continue

        if stripped.startswith(">"):
            flush_para()
            close_lists()
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip()[1:].strip())
                i += 1
            out.append("<blockquote><p>%s</p></blockquote>" % inline(" ".join(quote)))
            continue

        li = re.match(r"^(\s*)([-*]|\d+[.)])\s+(.*)$", line)
        if li:
            flush_para()
            ind, item = len(li.group(1)), li.group(3)
            kind = "ul" if li.group(2) in "-*" else "ol"
            if stack and ind <= stack[-1][0]:
                close_lists(ind)
                if stack and stack[-1][0] == ind:
                    if stack[-1][1] == kind:
                        out.append("</li>")
                    else:
                        out.append("</li></%s>" % stack.pop()[1])
            if not stack or ind > stack[-1][0]:
                out.append("<%s>" % kind)
                stack.append((ind, kind))
            i += 1
            # `- key: |` followed by a more-indented block -> literal <pre>.
            if item.rstrip().endswith("|"):
                block = []
                while i < len(lines) and (not lines[i].strip() or
                                          len(lines[i]) - len(lines[i].lstrip(" ")) > ind):
                    block.append(lines[i])
                    i += 1
                while block and not block[-1].strip():
                    block.pop()
                pad = min((len(b) - len(b.lstrip(" ")) for b in block if b.strip()), default=0)
                code = "\n".join(b[pad:] for b in block)
                out.append("<li>%s<pre><code>%s</code></pre>" % (
                    inline(item.rstrip()[:-1].rstrip()), html.escape(code)))
            else:
                out.append("<li>%s" % inline(item))
            continue

        if stack and indent > stack[-1][0]:  # continuation of a list item
            out[-1] += " " + inline(stripped)
            i += 1
            continue

        close_lists()
        para.append(stripped)
        i += 1

    flush_para()
    close_lists()
    return "\n".join(out)


def github_link(ref):
    m = re.match(r"^([\w.-]+/[\w.-]+)#(\d+)$", ref or "")
    return m and (m.group(1), m.group(2))


def render(md_text):
    fm, body = split_frontmatter(md_text)
    meta, nested = parse_frontmatter(fm)

    kind = "pull" if "pr" in meta else "issues"
    ref = meta.get("pr") or meta.get("issue") or ""
    title = meta.get("title") or ref or "Review"

    # Drop a leading H1; the header block below replaces it.
    body = re.sub(r"\A\s*#\s+[^\n]*\n", "", body)

    head = ["<h1>%s</h1>" % inline(title)]
    link = github_link(ref)
    info = []
    if link:
        url = "https://github.com/%s/%s/%s" % (link[0], kind, link[1])
        info.append('<a href="%s">%s</a>' % (html.escape(url), html.escape(ref)))
    for key in ("base", "head_sha", "main_sha", "state", "labels",
                "reviewed_at", "triaged_at"):
        if key in meta:
            val = meta[key]
            if key.endswith("sha"):
                val = val[:12]
            info.append("%s <code>%s</code>" % (key, html.escape(val)))
    head.append('<div class="meta">%s</div>' % " · ".join(info))

    badges = []
    if "verdict" in meta:
        badges.append('<span class="badge %s">verdict: %s</span>' % (
            color(meta["verdict"]), html.escape(meta["verdict"])))
    if "gate.decision" in meta:
        badges.append('<span class="badge %s">gate: %s</span>' % (
            color(meta["gate.decision"]), html.escape(meta["gate.decision"])))
    if badges:
        head.append('<div class="badges">%s</div>' % "".join(badges))
    if nested:
        head.append("<details><summary>Full metadata</summary><pre><code>%s</code></pre></details>"
                    % html.escape(fm))

    return ("<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
            "<title>%s</title><style>%s</style></head><body><main>\n%s\n%s\n</main></body></html>\n"
            % (html.escape(ref or title), CSS, "\n".join(head), render_body(body)))


def main(argv):
    if len(argv) not in (2, 3):
        sys.exit(__doc__.strip().splitlines()[-1])
    src = Path(argv[1])
    dst = Path(argv[2]) if len(argv) == 3 else src.with_suffix(".html")
    dst.write_text(render(src.read_text(encoding="utf-8")), encoding="utf-8")
    print(dst.resolve())


if __name__ == "__main__":
    main(sys.argv)
