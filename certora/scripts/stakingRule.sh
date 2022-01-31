if [ -z "$2" ]
  then
    echo "Incorrect number of arguments"
    echo ""
    echo "Usage: (from git root)"
    echo "  ./certora/scripts/`basename $0` [message describing the run]"
    echo ""
    exit 1
fi

rule=$1
msg=$2
shift 2


certoraRun certora/munged/RocketJoeStaking.sol \
    --verify RocketJoeStaking:certora/spec/staking.spec \
    --solc solc8.6                   \
    --solc_args '["--optimize"]' \
    --settings -t=600,-postProcessCounterExamples=true \
    --msg ${msg} \
    --cache RocketjoeStaking \
    --rule ${rule} \
    --staging \
    $*