use starknet::ContractAddress;
#[derive(Copy, Drop, Introspect, Serde)]
#[dojo::model]
pub struct Registration {
    #[key]
    pub tournament_id: u64,
    #[key]
    pub player_address: ContractAddress,
    pub is_registered: bool,
}

#[generate_trait]
pub impl RegistrationImpl of RegistrationTrait {
    #[inline(always)]
    fn is_registered(self: @Registration) -> bool {
        (*self).is_registered
    }
    #[inline(always)]
    fn register(ref self: Registration) {
        self.is_registered = true;
    }
    #[inline(always)]
    fn unregister(ref self: Registration) {
        self.is_registered = false;
    }
}