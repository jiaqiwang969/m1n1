# Guest4K Make Dev Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `make dev` operator entrypoint that opens the Guest4K mainline and launches Douyin.

**Architecture:** Keep `Makefile` as a thin convenience wrapper over `redroid/scripts/redroid_guest4k_107.sh`. The new targets should only sequence existing script actions and must not duplicate runtime logic.

**Tech Stack:** GNU Make, zsh script delegation, Python `unittest`, README documentation.

---

### Task 1: Test The New Make Targets First

**Files:**
- Create: `tests/redroid/test_make_dev.py`
- Modify: none
- Test: `tests/redroid/test_make_dev.py`

**Step 1: Write the failing test**

```python
def test_make_dev_invokes_guest4k_mainline_steps():
    result = run_make("-n", "dev")
    assert "redroid/scripts/redroid_guest4k_107.sh vm-start" in result.stdout
    assert "redroid/scripts/redroid_guest4k_107.sh restart-preserve-data" in result.stdout
    assert "redroid/scripts/redroid_guest4k_107.sh verify" in result.stdout
    assert "redroid/scripts/redroid_guest4k_107.sh viewer" in result.stdout
    assert "redroid/scripts/redroid_guest4k_107.sh douyin-start" in result.stdout
```

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest -q tests/redroid/test_make_dev.py`
Expected: FAIL because `dev` targets do not yet exist in `Makefile`

**Step 3: Write minimal implementation**

Add thin `Makefile` targets:

```make
REDROID_GUEST4K_SCRIPT := zsh redroid/scripts/redroid_guest4k_107.sh

dev-up:
	$(REDROID_GUEST4K_SCRIPT) vm-start
	$(REDROID_GUEST4K_SCRIPT) restart-preserve-data

dev-verify:
	$(REDROID_GUEST4K_SCRIPT) verify

dev-view:
	$(REDROID_GUEST4K_SCRIPT) viewer

dev-douyin:
	$(REDROID_GUEST4K_SCRIPT) douyin-start

dev: dev-up dev-verify dev-view dev-douyin
```

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest -q tests/redroid/test_make_dev.py`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/redroid/test_make_dev.py Makefile
git commit -m "make: add Guest4K dev entrypoint"
```

### Task 2: Document The One-Command Flow

**Files:**
- Modify: `README.md`
- Test: `tests/redroid/test_make_dev.py`

**Step 1: Write the failing test**

Extend the test file with an assertion that `make dev` is documented in `README.md`.

```python
def test_readme_documents_make_dev():
    text = README.read_text()
    assert "make dev" in text
```

**Step 2: Run test to verify it fails**

Run: `python3 -m pytest -q tests/redroid/test_make_dev.py`
Expected: FAIL until the README is updated

**Step 3: Write minimal implementation**

Add a short `README.md` section showing:

```bash
SUDO_PASS='...' make dev
```

and map it to the Guest4K mainline sequence.

**Step 4: Run test to verify it passes**

Run: `python3 -m pytest -q tests/redroid/test_make_dev.py`
Expected: PASS

**Step 5: Commit**

```bash
git add README.md tests/redroid/test_make_dev.py
git commit -m "docs: document make dev Guest4K flow"
```

### Task 3: Verify The Integrated Result

**Files:**
- Modify: `Makefile`
- Modify: `README.md`
- Test: `tests/redroid/test_make_dev.py`
- Test: `tests/redroid/test_redroid_guest4k_107.py`

**Step 1: Run targeted tests**

Run: `python3 -m pytest -q tests/redroid/test_make_dev.py`
Expected: PASS

**Step 2: Run the broader Redroid suite**

Run: `python3 -m pytest -q tests/redroid`
Expected: PASS

**Step 3: Dry-run the operator entrypoint**

Run: `make -n dev`
Expected: ordered Guest4K commands using `redroid/scripts/redroid_guest4k_107.sh`

**Step 4: Commit**

```bash
git add Makefile README.md tests/redroid/test_make_dev.py docs/plans/2026-03-21-guest4k-make-dev-design.md docs/plans/2026-03-21-guest4k-make-dev.md
git commit -m "make: add one-command Guest4K dev flow"
```
