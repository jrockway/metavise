.PHONY: start

start:
	killall -w -s 9 mongrel2 || echo "ok"
	make -C config start
