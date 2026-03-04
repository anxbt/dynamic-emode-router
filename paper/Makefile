# Makefile for LaTeX paper compilation

MAIN = main
PDF = $(MAIN).pdf

.PHONY: all clean view

all: $(PDF)

$(PDF): $(MAIN).tex sections/*.tex references.bib
	@echo "Compiling LaTeX document..."
	pdflatex $(MAIN).tex
	bibtex $(MAIN)
	pdflatex $(MAIN).tex
	pdflatex $(MAIN).tex
	@echo "✅ PDF compiled successfully: $(PDF)"

clean:
	rm -f *.aux *.bbl *.blg *.log *.out *.toc *.fdb_latexmk *.fls *.synctex.gz

view: $(PDF)
	open $(PDF)

# Quick compile without bibliography (faster for drafts)
draft: $(MAIN).tex sections/*.tex
	pdflatex $(MAIN).tex
	@echo "✅ Draft PDF compiled: $(PDF)"

help:
	@echo "Available targets:"
	@echo "  all     - Compile full paper with bibliography"
	@echo "  draft   - Quick compile without bibliography"
	@echo "  clean   - Remove auxiliary files"
	@echo "  view    - Open PDF in default viewer"
	@echo "  help    - Show this help"