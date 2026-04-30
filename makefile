.PHONY: help
help: makefile
	@tail -n +4 makefile | grep ".PHONY"


node_modules: package.json bun.lock
	if test ! -d $@; then npm install --force; fi


.PHONY: build
build: node_modules
	rm -rf build
	bunx tsc
	chmod +x build/cli/index.js


.PHONY: test
test: node_modules
	bun test


.PHONY: clean
clean:
	rm -rf node_modules
	rm -rf build
	rm -rf cli/*.js
	rm -rf src/*.js
	rm -rf test/*.js
