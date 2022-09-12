if [[ "$1" ]]
then
    RULE="--rule $1"
fi

if [[ "$2" ]]
then
    MSG=": $2"
fi


certoraRun  contracts/StakeManager.sol \
            contracts/BnbX.sol \
--link      StakeManager:bnbX=BnbX \
--verify    StakeManager:certora/specs/StakeManager.spec \
--packages  @openzeppelin=node_modules/@openzeppelin \
--path      . \
--loop_iter 3 \
--settings -optimisticFallback=true --optimistic_loop \
--staging \
$RULE  \
--msg "bnbx -$RULE $MSG"