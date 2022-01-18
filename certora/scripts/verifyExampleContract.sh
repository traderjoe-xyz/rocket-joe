
make -C certora munged

echo "TODO: fix the run script script"
exit 1

certoraRun
    certora/harness/ExampleHarness.sol \
    certora/helpers/DummyERC20A.sol    \
    certora/helpers/DummyERC20B.sol    \
    --verify ETokenHarness:certora/spec/example.spec \
    --solc solc8.0                      \
    --solc_args '["--optimize"]' \
    --settings -t=60,-postProcessCounterExamples=true \
    --msg "Example contract $1"                   \
    --staging \
    $*


