slot deployments delete evolute-duel torii
slot deployments delete evolute-duel katana
slot deployments create evolute-duel --team evolute --tier pro katana --config katana_config_release.toml
sozo build --release --unity
sozo migrate --release
slot deployments create evolute-duel --team evolute --tier pro torii --config torii_config_release.toml
sozo inspect --release
#slot deployments logs liyard-dojo-starter torii -f

