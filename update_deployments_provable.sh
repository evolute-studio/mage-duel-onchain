slot deployments delete evolute-duel-provable torii
slot deployments delete evolute-duel-provable katana
slot deployments create -t insane evolute-duel-provable katana --provable --chain-id 0 --block-time 30000
sozo build --profile provable --unity
sozo migrate --profile provable
slot deployments create -t insane evolute-duel-provable torii --config torii_config_provable
sozo inspect --profile provable
#slot deployments logs liyard-dojo-starter torii -f

