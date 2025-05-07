pub mod Errors {
    pub const INVALID_ENTRY: felt252            = 'TOURNAMENT: Invalid entry';
    pub const BUDOKAN_NOT_STARTABLE: felt252    = 'TOURNAMENT: Not startable';
    pub const BUDOKAN_NOT_PLAYABLE: felt252     = 'TOURNAMENT: Not playable';
    pub const ALREADY_STARTED: felt252          = 'TOURNAMENT: Already started';
    pub const ALREADY_ENLISTED: felt252         = 'TOURNAMENT: Already enlisted';
    pub const NOT_YOUR_ENTRY: felt252           = 'TOURNAMENT: Not your entry';
    pub const NOT_YOUR_DUELIST: felt252         = 'TOURNAMENT: Not your duelist';
    pub const INVALID_ENTRY_NUMBER: felt252     = 'TOURNAMENT: Invalid entry num';
    pub const TOURNAMENT_FULL: felt252          = 'TOURNAMENT: Full!';
    pub const INVALID_DUELIST: felt252          = 'TOURNAMENT: Invalid duelist';
    pub const DUELIST_IS_DEAD: felt252          = 'TOURNAMENT: Duelist is dead';
    pub const INSUFFICIENT_LIVES: felt252       = 'TOURNAMENT: Insufficient lives';
    pub const TOO_MANY_LIVES: felt252           = 'TOURNAMENT: Too many lives';
    pub const NOT_ENLISTED: felt252             = 'TOURNAMENT: Not enlisted';
    pub const NOT_STARTED: felt252              = 'TOURNAMENT: Not started';
    pub const HAS_ENDED: felt252                = 'TOURNAMENT: Has ended';
    pub const NOT_QUALIFIED: felt252            = 'TOURNAMENT: Not qualified';
    pub const DUELIST_IN_CHALLENGE: felt252     = 'TOURNAMENT: In a challenge';
    pub const DUELIST_IN_TOURNAMENT: felt252    = 'TOURNAMENT: In a tournament';
    pub const INVALID_ROUND: felt252            = 'TOURNAMENT: Invalid round';
    pub const STILL_PLAYABLE: felt252           = 'TOURNAMENT: Still playable';
    pub const CALLER_NOT_OWNER: felt252         = 'TOURNAMENT: Caller not owner';
    pub const IMPOSSIBLE_ERROR: felt252         = 'TOURNAMENT: Impossible error';
    pub const ALREADY_REGISTERED: felt252     = 'TOURNAMENT: Already registered';
    pub const INVALID_PASSWORD: felt252         = 'TOURNAMENT: Invalid password';
}