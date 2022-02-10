

certoraRun \
    certora/harness/LaunchEventHarness.sol \
    certora/harness/Owner.sol \
    certora/helpers/DummyERC20A.sol    \
    certora/helpers/DummyERC20B.sol    \
    certora/munged/RocketJoeFactory.sol    \
    certora/munged/RocketJoeToken.sol      \
    certora/helpers/DummyWeth.sol          \
    certora/munged/traderjoe/JoeRouter02.sol \
    certora/munged/traderjoe/JoePair.sol \
    certora/munged/traderjoe/libraries/JoeLibrary.sol \
    certora/munged/traderjoe/JoeFactory.sol \
    --link LaunchEventHarness:pair=JoePair \
    LaunchEventHarness:factory=JoeFactory \
    LaunchEventHarness:router=JoeRouter02 \
    LaunchEventHarness:rJoe=RocketJoeToken \
    LaunchEventHarness:rocketJoeFactory=RocketJoeFactory \
    LaunchEventHarness:WAVAX=DummyWeth \
            RocketJoeFactory:eventImplementation=LaunchEventHarness  RocketJoeFactory:rJoe=RocketJoeToken \
    --verify LaunchEventHarness:certora/spec/LEVarTran.spec \
    --solc_map Owner=solc8.6,JoeLibrary=solc6.12,LaunchEventHarness=solc8.6,DummyERC20A=solc8.6,DummyERC20B=solc8.6,RocketJoeFactory=solc8.6,RocketJoeToken=solc8.6,DummyWeth=solc8.6,JoeRouter02=solc6.12,JoePair=solc6.12,JoeFactory=solc6.12 \
    --optimistic_loop \
    --staging \
    --send_only \
    --rule "$1" \
    --rule_sanity \
    --msg "$1 var transition sanity"
