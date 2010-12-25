.PHONY: clean all start

config.sqlite: mongrel2.conf
	rm -f config.sqlite
	m2sh load -config mongrel2.conf -db config.sqlite

all: config.sqlite

clean:
	rm -f config.sqlite
	rm -rf service/*/supervise
	rm -rf service/*/log/supervise

start: config.sqlite
	svscan service
	make stop

stop:
	svc -x service/* service/*/log
	svc -k service/* service/*/log
