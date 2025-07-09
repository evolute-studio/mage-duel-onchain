slot deployments delete evolute-duel torii
slot deployments delete evolute-duel katana
slot deployments create evolute-duel --team evolute --tier pro katana --dev --dev.no-fee
sozo build --release --unity
sozo migrate --release
slot deployments create evolute-duel --team evolute --tier pro torii --config torii_config_release.toml --version v1.6.0-alpha.1
sozo inspect --release
#slot deployments logs liyard-dojo-starter torii -f

