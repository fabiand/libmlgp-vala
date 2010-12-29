
all: allpdf

allhtml: $(shell find . -name "*.rst" | sed 's/rst/html/')
allxhtml: $(shell find . -name "*.rst" | sed 's/rst/xhtml/')
allpdf: $(shell find . -name "*.rst" | sed 's/rst/pdf/')
alltex: $(shell find . -name "*.rst" | sed 's/rst/tex/')

%.html: %.rst
	rst2html $< > $@

%.xhtml: %.html
	sed "s/\\$$\\$$\(.*\)\\$$\\$$/\\\[\1\\\]/g" $< | $(TIDY)  | \
	$(itex2MML) > $@

%.tex: %.rst
	rst2latex --hyperlink-color 0 $< > $@

%.pdf: %.rst
	-rst2pdf $<

%.png: %.plot
	gnuplot $< > $@

clean-local:
	rm -f *.html *.pdf *.aux *.tex *.out *.log *.xhtml $(shell find . \
	-name "*.plot" | sed 's/\.plot$$/\.png/g')

clean: clean-local

install:
	echo install

uninstall:
	echo uninstall
