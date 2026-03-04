# Dynamic eMode Router Paper

This directory contains the LaTeX source code for the technical paper on the Dynamic eMode Router.

## Structure

```
paper/
├── main.tex              # Main LaTeX document
├── sections/             # Individual paper sections
│   ├── abstract.tex      # ✅ Complete
│   ├── introduction.tex  # ✅ Complete
│   ├── background.tex    # 🔲 TODO: Aave V3 technical details
│   ├── design.tex        # 🔲 TODO: Router architecture
│   ├── security.tex      # 🔲 TODO: Security analysis
│   ├── evaluation.tex    # 🔲 TODO: Real numbers go here
│   └── conclusion.tex    # 🔲 TODO: Summary and future work
├── references.bib        # Bibliography (BibTeX format)
├── Makefile              # Build automation
└── README.md             # This file
```

## Compiling the PDF

### Prerequisites
Make sure you have LaTeX installed:
```bash
brew install --cask mactex
```

### Build Commands
```bash
# Full compile with bibliography
make all

# Quick draft (faster, no bibliography)
make draft  

# Open PDF when done
make view

# Clean auxiliary files
make clean
```

### Manual Compilation (if make doesn't work)
```bash
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```

## Current Status

**Paper Version:** v0.1 - Initial Draft
**Completion:** Abstract ✅, Introduction ✅, Other sections 🔲

### What's Done
- [x] Paper structure and LaTeX setup
- [x] Abstract (complete)
- [x] Introduction with problem statement and contribution
- [x] Bibliography setup
- [x] Build system

### Next Steps
1. Fill in background section with Aave V3 technical details
2. Complete design section with router architecture
3. Add security analysis with invariants
4. **MOST IMPORTANT:** Fill evaluation section with real numbers from tests
5. Write conclusion

## Writing Notes

- The abstract mentions X%, Y% improvement numbers - these will come from your test results
- Introduction references Section labels that need to be filled in
- Each TODO section has specific guidance on what to write
- Keep adding to references.bib as you cite more sources

## Version History

- **v0.1** (March 2026) - Initial structure, abstract, introduction