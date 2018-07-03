PREFIX = /usr
PROGNAME = viswap

build:

install:
	install -m 0755 $(PROGNAME).pl $(PREFIX)/bin/$(PROGNAME)
