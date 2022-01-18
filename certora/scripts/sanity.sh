

certoraRun \
    certora/munged/LaunchEvent.sol \
    certora/helpers/DummyERC20A.sol    \
    certora/helpers/DummyERC20B.sol    \
    certora/munged/RocketJoeFactory.sol    \
    certora/munged/RocketJoeToken.sol      \
    certora/helpers/DummyWeth.sol          \
    certora/munged/traderjoe/JoeRouter02.sol \
    certora/munged/traderjoe/JoePair.sol \
    certora/munged/traderjoe/libraries/JoeLibrary.sol \
    certora/munged/traderjoe/JoeFactory.sol \
    --link LaunchEvent:pair=JoePair \
    LaunchEvent:factory=JoeFactory \
    LaunchEvent:router=JoeRouter02 \
    LaunchEvent:rJoe=RocketJoeToken \
    LaunchEvent:rocketJoeFactory=RocketJoeFactory \
    LaunchEvent:WAVAX=DummyWeth \
           RocketJoeFactory:eventImplementation=LaunchEvent  RocketJoeFactory:rJoe=RocketJoeToken \
    --verify LaunchEvent:certora/spec/sanity.spec \
    --solc_map JoeLibrary=solc6.12,LaunchEvent=solc8.6,DummyERC20A=solc8.6,DummyERC20B=solc8.6,RocketJoeFactory=solc8.6,RocketJoeToken=solc8.6,DummyWeth=solc8.6,JoeRouter02=solc6.12,JoePair=solc6.12,JoeFactory=solc6.12 \
    --staging \
    --msg "sanity launch" \
    # --staging \=
    $*

certoraRun \
    certora/munged/RocketJoeStaking.sol \
    certora/helpers/DummyERC20A.sol    \
    certora/helpers/DummyERC20B.sol    \
    certora/munged/RocketJoeToken.sol  \
    --link RocketJoeStaking:rJoe=RocketJoeToken \
    --verify RocketJoeStaking:certora/spec/sanity.spec \
    --solc solc8.6                      \
    --staging \
    --msg "sanity staking" \
    # --staging \=
    $*



