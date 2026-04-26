#!/usr/bin/env bash
set -euo pipefail

ASAR="app.asar"
WORK="app-unpacked"
BACKUP="app.asar.bak.$(date +%Y%m%d-%H%M%S)"

if [ ! -f "$ASAR" ]; then
  echo "ERROR: app.asar not found. Run this from the Resources directory."
  exit 1
fi

echo "Backing up $ASAR -> $BACKUP"
cp "$ASAR" "$BACKUP"

echo "Extracting app.asar..."
rm -rf "$WORK"
npx asar extract "$ASAR" "$WORK"

python3 <<'PY'
from pathlib import Path
import re

files = [
    "node_modules/@theia/core/lib/browser/tree/tree-widget.js",
    "lib/frontend/bundle.js",
    "lib/frontend/secondary-window.js",
]

toggle_re = re.compile(
    r"""doToggle\(event\) \{\s*
\s*const nodeId = event\.currentTarget\.getAttribute\('data-node-id'\);\s*
\s*if \(nodeId\) \{\s*
\s*const node = this\.model\.getNode\(nodeId\);\s*
\s*if \(node && this\.props\.expandOnlyOnExpansionToggleClick\) \{\s*
\s*if \(this\.isExpandable\(node\) && !this\.hasShiftMask\(event\) && !this\.hasCtrlCmdMask\(event\)\) \{\s*
\s*this\.model\.toggleNodeExpansion\(node\);\s*
\s*\}\s*
\s*\}\s*
\s*else \{\s*
\s*this\.handleClickEvent\(node, event\);\s*
\s*\}\s*
\s*\}\s*
\s*event\.stopPropagation\(\);\s*
\s*\}""",
    re.MULTILINE
)

tap_re = re.compile(
    r"""tapNode\(node\) \{\s*
\s*if \(tree_selection_1\.SelectableTreeNode\.is\(node\)\) \{\s*
\s*this\.model\.selectNode\(node\);\s*
\s*\}\s*
\s*if \(node && !this\.props\.expandOnlyOnExpansionToggleClick && this\.isExpandable\(node\)\) \{\s*
\s*this\.model\.toggleNodeExpansion\(node\);\s*
\s*\}\s*
\s*\}""",
    re.MULTILINE
)

dbl_re = re.compile(
    r"""handleDblClickEvent\(node, event\) \{\s*
\s*this\.model\.openNode\(node\);\s*
\s*event\.stopPropagation\(\);\s*
\s*\}""",
    re.MULTILINE
)

toggle_patch = """doToggle(event) {
        const nodeId = event.currentTarget.getAttribute('data-node-id');
        if (nodeId) {
            const node = this.model.getNode(nodeId);
            if (node && this.isExpandable(node) && !this.hasShiftMask(event) && !this.hasCtrlCmdMask(event)) {
                this.model.toggleNodeExpansion(node);
            }
            else {
                this.handleClickEvent(node, event);
            }
        }
        event.stopPropagation();
    }"""

tap_patch = """tapNode(node) {
        if (tree_selection_1.SelectableTreeNode.is(node)) {
            this.model.selectNode(node);
        }
    }"""

dbl_patch = """handleDblClickEvent(node, event) {
        if (node && this.isExpandable(node)) {
            this.model.toggleNodeExpansion(node);
        }
        else {
            this.model.openNode(node);
        }
        event.stopPropagation();
    }"""

root = Path("app-unpacked")

for rel in files:
    path = root / rel
    if not path.exists():
        print(f"SKIP missing: {rel}")
        continue

    text = path.read_text()
    original = text

    text, toggle_count = toggle_re.subn(toggle_patch, text)
    text, tap_count = tap_re.subn(tap_patch, text)
    text, dbl_count = dbl_re.subn(dbl_patch, text)

    if text != original:
        path.write_text(text)
        print(f"PATCHED {rel}: toggle={toggle_count}, tap={tap_count}, dbl={dbl_count}")
    else:
        print(f"NO CHANGE {rel}: pattern not found or already patched")
PY

echo "Repacking app.asar..."
npx asar pack "$WORK" "$ASAR"

echo "Done."
echo "Backup saved as: $BACKUP"
echo "Restart CCS Theia."
