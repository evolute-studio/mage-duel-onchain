/// Represents a shop where players can purchase in-game items.
///
/// - `shop_id`: Unique identifier for the shop.
/// - `skin_prices`: List of prices for different skins available in the shop.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Shop {
    #[key]
    pub shop_id: felt252,
    pub skin_prices: Array<u32>,
}
