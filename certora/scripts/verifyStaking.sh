
if [ -z "$1" ]
  then
    echo "Incorrect number of arguments"
    echo ""
    echo "Usage: (from git root)"
    echo "  ./certora/scripts/`basename $0` [message describing the run]"
    echo ""
    exit 1
fi

msg=$1
shift 1

certoraRun certora/harness/RocketJoeStakingHarness.sol \
           certora/helpers/DummyERC20Impl.sol \
           certora/munged/RocketJoeToken.sol  \
    --verify RocketJoeStakingHarness:certora/spec/Staking.spec \
    --optimistic_loop --loop_iter 1 \
    --solc solc8.6  \
    --solc_args '["--optimize"]' \
    --settings -t=600,-postProcessCounterExamples=true \
    --link RocketJoeStakingHarness:joe=DummyERC20Impl \
    --link RocketJoeStakingHarness:rJoe=RocketJoeToken \
    --cache RocketJoeStaking \
    --msg "${msg}" \
    # --staging \
