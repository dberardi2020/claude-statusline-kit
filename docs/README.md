# Claude Code Statusline Kit — Documentation

The map of this folder. Four kinds of doc, by audience and purpose:

| Folder / file | For whom | Purpose |
|---|---|---|
| **[product/](product/README.md)** | *any* stakeholder | What the kit is, what it shows, and how to install and read it — no code assumed. |
| **[technical/](technical/README.md)** | developers | How it's built — architecture, the rendering spec, the two implementations, install, testing. |
| **[decisions/](decisions/README.md)** | anyone going deep | Architecture Decision Records — *why* each choice was made. Start with [0001](decisions/0001-two-native-shell-scripts-over-node.md); nearly everything follows from it. |
| **[tickets/](tickets/tickets.md)** | maintainers | The lightweight backlog (board-first, no external tracker). |

## Where to start

- **New to the kit?** → [product/overview.md](product/overview.md), then
  [product/concepts.md](product/concepts.md).
- **Going to use it?** → [product/user-guide.md](product/user-guide.md).
- **Going to work on the code?** → [technical/architecture.md](technical/architecture.md),
  then [technical/rendering.md](technical/rendering.md) — the spec both implementations
  must satisfy.
- **Changing the output?** → [technical/rendering.md](technical/rendering.md) is the
  contract, and [technical/testing.md](technical/testing.md) tells you how to regenerate the
  goldens afterwards.

## How these relate

`decisions/` is the **primary source** — the decision history. `product/` and `technical/`
are the **reader-facing suites** that synthesize it for their audiences and link back rather
than duplicate. When they disagree, the ADRs win (they carry the current decision state).

The concept model lives in **[product/concepts.md](product/concepts.md)** and nowhere else —
there is deliberately no second top-level concept doc restating it.

Within `technical/`, one doc is normative rather than descriptive:
**[rendering.md](technical/rendering.md) is the specification.** Both implementations must
satisfy it byte-for-byte; where they disagree, one of them has a bug.

The user-facing quickstart lives in the repo [README](../README.md); the styled one-page
reference is [statusline.html](statusline.html).

## Doc convention

Filenames are lowercase kebab-case (`README.md` is the one exception), folders are lowercase,
and ticket IDs stay uppercase. Every folder holding more than one prose doc carries a
`README.md` index.

Every prose doc is a **Markdown + HTML pair** in lock-step: the `.md` is the source of
truth, the `.html` is a styled render of the same content. After editing a `.md`,
regenerate its `.html`:

```sh
python docs/render.py docs/<path>/<file>.md      # one file
python docs/render.py docs/technical/*.md        # a whole folder
```

`render.py` is stdlib-only; there's no other docs build step. The one exception is
[statusline.html](statusline.html), which is hand-maintained and has no `.md` source.
