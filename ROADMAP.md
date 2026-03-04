# Dynamic eMode Aave Router — Project Roadmap & Tracker

## What Is This Project?
A smart contract router built on top of Aave V3 that dynamically manages
eMode switching to improve capital efficiency, borrow capacity, and reduce
liquidation risk for users.

---

## What Is the Goal?
1. Build a production-grade protocol (not just a demo project)
2. Write a technical paper with real numbers
3. Publish it on ArXiv and ethresear.ch
4. Enter the protocol engineer circle

---

## Key Concepts to Know

### ArXiv (arxiv.org)
- Free website run by Cornell University
- Where researchers upload papers before formal peer review
- Think of it like GitHub but for research papers
- Used by real protocol engineers, quant researchers, academics
- No fees, no gatekeeping — just upload a PDF
- Your paper gets a permanent link you can share anywhere

### ethresear.ch
- Ethereum's own research forum
- Read by actual Ethereum core developers and protocol engineers
- Posting here gets you noticed by the right people
- Free to post

### Foundry Fork Testing
- Lets you take a snapshot of real Ethereum mainnet at a past block
- Test your router against real historical Aave pool states
- Replay historical crashes (e.g., LUNA May 2022) locally
- Command: `anvil --fork-url YOUR_ALCHEMY_URL --fork-block-number 19000000`

### Monte Carlo Simulation
- Run the same scenario thousands of times with random inputs
- Tells you: "In X% of market conditions, a user gets liquidated"
- Written in Python, not Solidity
- Gives you the REAL NUMBERS your paper needs

### Risk-Adjusted Capital Efficiency
- Capital Efficiency = how much you can borrow vs what you deposit
- Risk-Adjusted = is that borrowing power worth the liquidation risk?
- Example real number: "Router improved borrow capacity by 31% while
  reducing liquidation probability by 28%"

### Economic Modeling
- Using math and data to predict system behavior under market stress
- Not guessing — calculating
- Example: "If ETH drops 40% in 1 hour, how many users get liquidated?"

---

## Folder Structure (Growing Into This)

```
dynamic-emode-aaveRouter/
├── src/                          # Your smart contracts
├── test/
│   ├── unit/                     # Isolated function tests (START HERE)
│   ├── integration/              # Fork tests against real Aave
│   ├── invariant/                # What you already have ✅
│   ├── simulation/               # Stress tests (price collapse scenarios)
│   └── helpers/                  # Shared setup, mock oracles
├── analysis/                     # Python layer
│   ├── monte_carlo.py
│   ├── capital_efficiency.py
│   ├── liquidation_risk.py
│   ├── data/
│   │   └── results.csv
│   └── charts/
│       └── price_paths.png
├── paper/                        # Your LaTeX paper
│   ├── main.tex
│   ├── sections/
│   │   ├── abstract.tex
│   │   ├── introduction.tex
│   │   ├── background.tex
│   │   ├── design.tex
│   │   ├── security.tex
│   │   ├── evaluation.tex        # Real numbers go here
│   │   └── conclusion.tex
│   └── main.pdf                  # Export and upload this
├── ROADMAP.md                    # This file
└── README.md
```

---

## The Real Numbers You Need For Your Paper

| Metric | Symbol | How to Get It |
|--------|--------|---------------|
| Capital efficiency improvement | X% | Compare LTV before/after router |
| Borrow capacity increase | Y% | Compare max borrow before/after |
| Gas cost reduction | Z% | Foundry gas snapshots |
| Worst case liquidation delta | Q | Fork tests on historical crash blocks |

These numbers come from your tests and Python simulations.
You cannot write the paper without them.
The paper GROWS alongside the work — not after it.

---

## Dopamine Checkpoints 🎯

### ✅ Checkpoint 0 — Where You Are Now
- [x] Basic router contract written
- [x] Some basic tests written
- [x] Some invariants written
- [ ] Test coverage measured

---

### ✅ Checkpoint 1 — "The Draft" (Target: 2-3 weeks) — **COMPLETED!**
**Code goals:**
- [ ] Unit tests for all core functions
- [ ] Test coverage above 60%
- [x] `/analysis` folder created ✅
- [x] First Monte Carlo script written (even if simple) ✅

**Paper goals:**
- [x] `/paper` folder created ✅
- [x] Abstract written ✅
- [x] Introduction written ✅
- [x] LaTeX setup complete ✅
- [x] PDF compilation working ✅
- [ ] Architecture diagram sketched

**Milestone:** ✅ **ACHIEVED** — v0.1 PDF compiled successfully!
**What your paper says at this point:**
> "This paper presents a dynamic eMode router for Aave V3.
> Initial test coverage covers core switching logic."

---

### 🔲 Checkpoint 2 — "The Numbers" (Target: 4-6 weeks)
**Code goals:**
- [ ] Fork tests against real Aave mainnet complete
- [ ] Monte Carlo simulation producing price paths
- [ ] Capital efficiency numbers calculated
- [ ] results.csv populated with real data

**Paper goals:**
- [ ] Background section written (explain Aave eMode)
- [ ] Design section written (your router architecture)
- [ ] Evaluation section started with real numbers

**Milestone:** Upload v0.2 PDF to GitHub
**What your paper says:**
> "Capital efficiency improved by X%. Borrow capacity increased
> by Y% under standard volatility conditions."

---

### 🔲 Checkpoint 3 — "The Hardened Protocol" (Target: 8-10 weeks)
**Code goals:**
- [ ] 90%+ test coverage
- [ ] Invariant suite complete and passing
- [ ] Stress tests against LUNA crash block (May 2022)
- [ ] Multi-user competing borrow scenarios tested
- [ ] Flash loan interaction tests written

**Paper goals:**
- [ ] Security section written
- [ ] All sections complete
- [ ] Numbers finalized

**Milestone:** Upload v0.3 PDF to GitHub
**What your paper says:**
> "The router survived conditions mirroring the May 2022 LUNA
> collapse with worst-case liquidation delta Q = [your number]."

---

### 🔲 Checkpoint 4 — "Publication" (Target: 12-16 weeks)
**Goals:**
- [ ] Full paper proofread
- [ ] Upload to ArXiv (arxiv.org) — free
- [ ] Post on ethresear.ch — free
- [ ] Share on Twitter/X with paper link
- [ ] README updated to link to paper

**Milestone:** You are now a published protocol researcher.

---

## Where to Publish (In Order of Effort)

| Platform | Effort | Credibility | Link |
|----------|--------|-------------|------|
| GitHub (PDF in repo) | Very Low | Shows intent | your repo |
| ArXiv | Low | Legitimate academic record | arxiv.org |
| ethresear.ch | Low | Seen by protocol engineers | ethresear.ch |
| Ethereum Magicians | Medium | Community discussion | ethereum-magicians.org |
| IEEE / ACM conferences | Very High | Full academic credentials | - |

**Start with ArXiv + ethresear.ch. That is enough.**

---

## Installing LaTeX on Mac (For Writing Your Paper)
```bash
brew install --cask mactex
```
Then use VSCode with the LaTeX Workshop extension to write and export PDF.

---

## Current Status
**Last updated:** March 2026
**Stage:** ✅ Checkpoint 1 COMPLETED → Working toward Checkpoint 2
**Test coverage:** Unknown (needs to be measured)
**Paper status:** v0.1 Draft — Abstract ✅, Introduction ✅, PDF compiling ✅

---

## Notes & Decisions Log
- Project started as a KDI dummy project
- Goal is to separate this into a standalone published protocol paper
- Python analysis layer will live in `/analysis` folder
- Paper will be written in LaTeX, exported as PDF, versioned in repo
