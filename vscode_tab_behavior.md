# VS Code Double-Click Tab Behavior (Accurate Behavior)

## 🧠 Core Idea

VS Code does **not** maximize the whole window and does **not completely hide other editor tabs/groups**.

Instead:

> It expands the selected **editor group** to occupy most (or all) of the editor area, while preserving the layout structure and keeping other groups in a collapsed or minimal state.

---

## 🧱 Mental Model: Editor Groups

VS Code organizes editors like this:

```
Workbench
 ├─ Sidebar (Explorer, etc.)
 ├─ Editor Area
 │   ├─ Group A (left)
 │   ├─ Group B (right)
 │   └─ Group C (bottom)
 └─ Panel (terminal, etc.)
```

Each **group**:
- Contains tabs
- Has one active editor
- Is arranged using a **grid/split layout**

---

## 🖱️ Double-Click Behavior

### When you double-click a tab:

1. Identify the **editor group** that owns the tab
2. Toggle its layout state:
   - If not expanded → expand it
   - If expanded → restore layout

---

## 🔼 Expand Behavior (What Actually Happens)

VS Code:

- Expands the selected group to fill most of the editor area
- **Collapses other groups to minimal size**, rather than removing them
- Keeps layout structure intact

### Example

**Before:**

```
+---------------------+---------------------+
| Group A             | Group B             |
| [a.c]               | [b.c]               |
+---------------------+---------------------+
```

**After double-click (Group A):**

```
+------------------------------------------+
| Group A                                  |
| [a.c]                                    |
+------------------+-----------------------+
| (collapsed B)    |                       |
+------------------+-----------------------+
```

👉 Group B is not deleted — just minimized.

---

## 🔽 Restore Behavior

Double-click again:

- Restores the exact previous layout
- Keeps:
  - group sizes
  - split orientation
  - group order

---

## ⚙️ Important Details

### 1. Only affects editor area

These are NOT affected:
- Sidebar (Explorer)
- Bottom panel (terminal, problems)
- Activity bar

---

### 2. Layout state is preserved

VS Code keeps an internal layout model:

```
grid layout snapshot
```

So restore is exact.

---

### 3. Works for all layouts

#### Horizontal split
```
A | B
```

#### Vertical split
```
A
---
B
```

#### Grid layout
```
A | B
-----
C
```

Behavior:
- One group expands
- Others shrink to minimal presence (not hidden)

---

### 4. Not DOM-based

VS Code uses a **layout engine (GridView)**:

- Adjusts split sizes
- Does NOT:
  - remove DOM nodes
  - hide elements with display:none

---

## 🧩 Key Difference vs Simple DOM Hiding

| Behavior | VS Code | Simple Patch |
|--------|--------|--------------|
| Other groups | Collapsed/minimized | Fully hidden |
| Layout engine | Yes | No |
| Restore accuracy | Exact | Depends |
| Visual continuity | Preserved | Lost |

---

## 🎯 Correct Behavior Specification

ON DOUBLE CLICK:
- Identify editor group
- Resize layout so:
  - selected group = large
  - others = minimal size (not zero, not hidden)

ON SECOND DOUBLE CLICK:
- Restore layout exactly

---

## 🚧 Implication for Theia

To match VS Code exactly:

```text
Do NOT hide nodes with display:none
Instead:
→ modify split panel sizes
→ keep all groups alive
```

This means:

- You must interact with **Lumino DockPanel layout**
- Not just DOM visibility

---

## 🧠 Summary

VS Code does:

```text
Resize layout intelligently
```

NOT:

```text
Hide everything else
```
