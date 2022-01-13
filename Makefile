.PHONY: test coverage

compile:
	yarn run hardhat compile

test:
	yarn run hardhat test

clean:
	yarn run hardhat clean

coverage:
	yarn run hardhat coverage

console:
	yarn run hardhat console

size:
	yarn run hardhat size-contracts
