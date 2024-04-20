.PHONY: build
build:
	bun x tsc


.PHONY: test
test:
	bun test


.PHONY: clean
clean:
	rm -rf node_modules
	rm -rf build
	rm -rf cli/*.js
	rm -rf src/*.js
	rm -rf test/*.js
