all: build test

build:
	dune build src

test: build
	dune runtest

clean:
	rm -rf _build
