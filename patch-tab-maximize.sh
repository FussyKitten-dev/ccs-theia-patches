#!/usr/bin/env bash
set -euo pipefail

ASAR="app.asar"
WORK="app-unpacked"
BACKUP="app.asar.tabs.bak.$(date +%Y%m%d-%H%M%S)"

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

files = [
    "node_modules/@theia/core/lib/browser/shell/tab-bars.js",
    "lib/frontend/bundle.js",
    "lib/frontend/secondary-window.js",
]

start_marker = "this.handleDblClickEvent = (event) => {"
end_marker = "\n        if (this.decoratorService) {"

tab_patch = """this.handleDblClickEvent = (event) => {
            if (!this.tabBar || !(event.currentTarget instanceof HTMLElement)) {
                return;
            }

            const id = event.currentTarget.id;
            const title = this.tabBar.titles.find(t => this.createTabId(t) === id);
            const widget = title === null || title === void 0 ? void 0 : title.owner;
            const area = widget === null || widget === void 0 ? void 0 : widget.parent;

            if (!area || typeof area.saveLayout !== 'function' || typeof area.restoreLayout !== 'function') {
                return;
            }

            if (area.id === 'theia-main-content-panel' || area.id === 'theia-bottom-content-panel') {
                if (area._tabMaximizeRestoreLayout) {
                    const saved = area._tabMaximizeRestoreLayout;
                    area._tabMaximizeRestoreLayout = undefined;
                    area.restoreLayout(saved);
                }
                else {
                    // Collect the widgets belonging to the double-clicked tab bar.
                    const myWidgets = new Set(
                        this.tabBar.titles.map(t => t.owner).filter(Boolean)
                    );

                    // Deep-clone a layout config node, preserving widget references.
                    const cloneNode = (node) => {
                        if (!node) { return node; }
                        if (node.type === 'tab-area') {
                            return { type: 'tab-area', widgets: node.widgets.slice(), currentIndex: node.currentIndex };
                        }
                        return {
                            type: 'split-area',
                            orientation: node.orientation,
                            children: node.children.map(cloneNode),
                            sizes: node.sizes.slice()
                        };
                    };

                    // Return true if a config node contains any widget from wset.
                    const nodeContains = (node, wset) => {
                        if (!node) { return false; }
                        if (node.type === 'tab-area') { return node.widgets.some(w => wset.has(w)); }
                        return node.children.some(c => nodeContains(c, wset));
                    };

                    // Recursively collapse sibling branches to MIN_COLLAPSED px
                    // while expanding the branch that contains the target group.
                    const MIN_COLLAPSED = 40;
                    const expandToFront = (node, wset) => {
                        if (!node || node.type === 'tab-area') { return; }
                        const targetIdx = node.children.findIndex(c => nodeContains(c, wset));
                        if (targetIdx === -1) { return; }
                        let total = node.sizes.reduce((a, b) => a + b, 0);
                        if (total < node.sizes.length * MIN_COLLAPSED) { total = node.sizes.length * 400; }
                        const targetSize = Math.max(total - (node.sizes.length - 1) * MIN_COLLAPSED, MIN_COLLAPSED);
                        node.sizes = node.sizes.map((_, i) => i === targetIdx ? targetSize : MIN_COLLAPSED);
                        expandToFront(node.children[targetIdx], wset);
                    };

                    const saved = area.saveLayout();
                    area._tabMaximizeRestoreLayout = saved;
                    const expanded = { main: cloneNode(saved.main) };
                    expandToFront(expanded.main, myWidgets);
                    area.restoreLayout(expanded);
                }
                event.stopPropagation();
            }
        };"""

root = Path("app-unpacked")

for rel in files:
    path = root / rel
    if not path.exists():
        print(f"SKIP missing: {rel}")
        continue

    text = path.read_text()
    start = text.find(start_marker)
    if start == -1:
        print(f"NO CHANGE {rel}: start marker not found")
        continue

    end = text.find(end_marker, start)
    if end == -1:
        print(f"NO CHANGE {rel}: end marker not found")
        continue

    new_text = text[:start] + tab_patch + text[end:]

    if new_text != text:
        path.write_text(new_text)
        print(f"PATCHED {rel}: handlers=1")
    else:
        print(f"NO CHANGE {rel}: already patched")

PY

echo "Repacking app.asar..."

echo "Running syntax checks on patched files..."
node --check "$WORK/node_modules/@theia/core/lib/browser/shell/tab-bars.js"
node --check "$WORK/lib/frontend/bundle.js"
node --check "$WORK/lib/frontend/secondary-window.js"

npx asar pack "$WORK" "$ASAR"

echo "Done."
echo "Backup saved as: $BACKUP"
echo "Restart CCS Theia."