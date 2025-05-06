pub mod Errors {
    pub const INVALID_CALLER: felt252           = 'DUEL: Invalid caller';
    pub const INVALID_DUELIST: felt252          = 'DUEL: Invalid duelist';
    pub const INVALID_DUELIST_A_NULL: felt252   = 'DUEL: Duelist A null';
    pub const INVALID_DUELIST_B_NULL: felt252   = 'DUEL: Duelist B null';
    pub const INVALID_CHALLENGED_SELF: felt252  = 'DUEL: Challenged self';
    pub const INVALID_DUEL_TYPE: felt252        = 'DUEL: Invalid duel type';
    pub const INVALID_REPLY_SELF: felt252       = 'DUEL: Reply self';
    pub const INVALID_CHALLENGE: felt252        = 'DUEL: Invalid challenge';
    pub const NOT_YOUR_CHALLENGE: felt252       = 'DUEL: Not your challenge';
    pub const NO_CALLENGE: felt252              = 'DUEL: No challenge';
    pub const NOT_REGISTERED: felt252           = 'DUEL: Not registered';
    pub const NOT_YOUR_DUELIST: felt252         = 'DUEL: Not your duelist';
    pub const DUELIST_IS_DEAD_A: felt252        = 'DUEL: Duelist A is dead!';
    pub const DUELIST_IS_DEAD_B: felt252        = 'DUEL: Duelist B is dead!';
    pub const INSUFFICIENT_LIVES_A: felt252     = 'DUEL: Insufficient lives A';
    pub const INSUFFICIENT_LIVES_B: felt252     = 'DUEL: Insufficient lives B';
    // pub const CHALLENGER_NOT_ADMITTED: felt252  = 'DUEL: Challenger not allowed';
    // pub const CHALLENGED_NOT_ADMITTED: felt252  = 'DUEL: Challenged not allowed';
    pub const CHALLENGE_NOT_AWAITING: felt252   = 'DUEL: Challenge not Awaiting';
    pub const PACT_EXISTS: felt252              = 'DUEL: Pact exists';
    pub const DUELIST_IN_CHALLENGE: felt252     = 'DUEL: Duelist in a challenge';
}