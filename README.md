# CCS Theia Patches

Quality-of-life patches for **Code Composer Studio 2050** (the Theia-based IDE).  
Each patch is a self-contained shell script that backs up, modifies, and repacks the `app.asar` bundle.

---

## Patches

### 1. `patch-tab-maximize.sh` — VS Code-style tab double-click maximize

Double-clicking an editor tab expands that editor group to fill the editor area, collapsing sibling groups to their tab-bar height (~40 px). Double-clicking again restores the previous layout exactly.

**Behavior:**
- Sidebar, activity bar, and bottom panel are **not affected**
- All editor groups remain alive in the layout (none are hidden or removed)
- Restore is exact — group sizes, split orientation, and order are all preserved
- Works for horizontal splits, vertical splits, and grid layouts

**Before:**
```
┌──────────────────┬──────────────────┐
│  Group A         │  Group B         │
│  [file-a.c]      │  [file-b.c]      │
└──────────────────┴──────────────────┘
```

**After double-clicking a tab in Group A:**
```
┌────────────────────────────────┬─────┐
│  Group A                       │ (B) │
│  [file-a.c]                    │     │
└────────────────────────────────┴─────┘
```

Double-click again → original layout restored.

---

### 2. `patch-folder-expansion.sh` — Single-click select, double-click expand

Changes the tree widget (Project Explorer, etc.) so that:

| Action | Before | After |
|--------|--------|-------|
| Single click | Select + expand/collapse | Select only |
| Double click | Open file | Toggle expand/collapse (folders) or open (files) |

This matches the behavior of most file explorers and VS Code's default tree interaction.

---

## Requirements

- macOS
- Node.js with `npx` available (`node --version`, `npx --version`)
- Code Composer Studio 2050 installed at the default path  
  (`/Applications/ti/ccs2050/ccs/Code Composer Studio.app`)

---

## Usage

Run from the `Resources` directory of the CCS install:

```bash
cd "/Applications/ti/ccs2050/ccs/Code Composer Studio.app/Contents/Resources"

# Apply tab maximize patch
./patch-tab-maximize.sh

# Apply folder expansion patch
./patch-folder-expansion.sh
```

Then restart CCS Theia.

Each script:
1. Creates a timestamped backup of `app.asar` before making any changes
2. Extracts the archive, applies the patch, validates JS syntax
3. Repacks `app.asar`

---

## Restoring the Original

Each script saves a backup named `app.asar.tabs.bak.YYYYMMDD-HHMMSS` (tab patch) or `app.asar.bak.YYYYMMDD-HHMMSS` (folder patch) in the same directory. To revert:

```bash
cd "/Applications/ti/ccs2050/ccs/Code Composer Studio.app/Contents/Resources"
cp app.asar.tabs.bak.<timestamp> app.asar
```

---

## How It Works

### Tab maximize

The Theia tab bar renderer has a `handleDblClickEvent` handler that by default does nothing on editor tabs. The patch replaces it with a handler that:

1. Finds the Lumino `DockPanel` that owns the clicked tab bar
2. On first double-click: calls `area.saveLayout()` to snapshot the layout, then calls `area.restoreLayout()` with a cloned config where sibling split sizes are collapsed to 40 px
3. On second double-click: calls `area.restoreLayout()` with the original snapshot

This operates entirely through Lumino's layout engine — no DOM manipulation.

### Folder expansion

The tree widget's `tapNode` method normally both selects and expands a node on single click. The patch removes the expansion from single click and moves it to `handleDblClickEvent`, where folders toggle expansion and files open normally.

---

## Compatibility

Tested against **CCS 2050** (`app.asar` from April 2026 build). The patches use string markers to locate the exact code sections, so they will print `NO CHANGE: pattern not found` if a future CCS version changes the surrounding code rather than silently corrupting the bundle.
