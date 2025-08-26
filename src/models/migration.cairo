use starknet::ContractAddress;

// --------------------------------------
// Migration Models
// --------------------------------------

/// Represents a migration request from a guest account to a controller account.
///
/// - `guest_address`: The address of the guest account requesting migration.
/// - `controller_address`: The target controller address to migrate to.
/// - `requested_at`: Timestamp when the migration was requested.
/// - `expires_at`: Timestamp when the request expires.
/// - `status`: Current status of the migration (0: pending, 1: approved, 2: rejected, 3:
/// completed).
#[derive(Drop, Serde, Copy, Introspect, Debug)]
#[dojo::model]
pub struct MigrationRequest {
    #[key]
    pub guest_address: ContractAddress,
    pub controller_address: ContractAddress,
    pub requested_at: u64,
    pub expires_at: u64,
    pub status: u8, // 0: pending, 1: approved, 2: rejected, 3: completed
}

#[generate_trait]
pub impl MigrationRequestImpl of MigrationRequestTrait {
    fn is_pending(self: @MigrationRequest) -> bool {
        *self.status == 0
    }

    fn is_approved(self: @MigrationRequest) -> bool {
        *self.status == 1
    }

    fn is_rejected(self: @MigrationRequest) -> bool {
        *self.status == 2
    }

    fn is_completed(self: @MigrationRequest) -> bool {
        *self.status == 3
    }

    fn is_expired(self: @MigrationRequest, current_time: u64) -> bool {
        *self.expires_at <= current_time
    }

    fn can_be_executed(self: @MigrationRequest, current_time: u64) -> bool {
        self.is_approved() && !self.is_expired(current_time)
    }
}
