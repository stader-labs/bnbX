certoraRun  certora/harness/StakeManagerHarness.sol \
            contracts/StakeManager.sol \
            contracts/BnbX.sol \
--link      StakeManager:bnbX=BnbX \
--verify    StakeManagerHarness:certora/specs/StakeManager.spec \
--packages  @openzeppelin=node_modules/@openzeppelin \
--path      . \
--loop_iter 3 \
--settings -optimisticFallback=true --optimistic_loop \
--staging \
--msg "bnbx"
