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

certoraRun certora/munged/RocketJoeStaking.sol \
           certora/helpers/DummyERC20Impl.sol \
           certora/munged/RocketJoeToken.sol  \
    --verify RocketJoeStaking:certora/spec/staking.spec \
    --optimistic_loop --loop_iter 1 \
    --solc solc8.6  \
    --solc_args '["--optimize"]' \
    --settings -t=600,-postProcessCounterExamples=true \
    --cache RocketJoeStaking \
  --msg "${msg}" \
    --staging \