compile:
	yarn run hardhat compile

.PHONY: test
test:
	yarn run hardhat test

clean:
	yarn run hardhat clean

coverage:
	yarn run hardhat coverage

console:
	yarn run hardhat console
