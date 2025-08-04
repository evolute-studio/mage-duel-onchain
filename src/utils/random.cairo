/// Simple cross-platform compatible random utilities
/// Uses Linear Congruential Generator for deterministic randomness
/// Compatible with Unity C# implementation

// LCG constants (same as glibc's rand())
const LCG_A: u64 = 1103515245;
const LCG_C: u64 = 12345;
const LCG_M: u64 = 2147483648; // 2^31

/// Hash a single u32 value using LCG
pub fn hash_u32(value: u32) -> u32 {
    let val_u64: u64 = value.into();
    let result = (LCG_A * val_u64 + LCG_C) % LCG_M;
    result.try_into().unwrap()
}

/// Hash two u32 values 
pub fn hash_u32_pair(a: u32, b: u32) -> u32 {
    let hash_a = hash_u32(a);
    let hash_b = hash_u32(b);
    hash_u32(hash_a ^ hash_b)
}

/// Hash three u32 values
pub fn hash_u32_triple(a: u32, b: u32, c: u32) -> u32 {
    let hash_ab = hash_u32_pair(a, b);
    hash_u32_pair(hash_ab, c)
}

/// Hash four u32 values  
pub fn hash_u32_quad(a: u32, b: u32, c: u32, d: u32) -> u32 {
    let hash_ab = hash_u32_pair(a, b);
    let hash_cd = hash_u32_pair(c, d);
    hash_u32_pair(hash_ab, hash_cd)
}

/// Convert felt252 to u32 for hashing (takes lower 32 bits)
pub fn felt252_to_u32(value: felt252) -> u32 {
    let value_u256: u256 = value.into();
    let value_u32: u32 = (value_u256 & 0xFFFFFFFF).try_into().unwrap();
    value_u32
}

/// Hash felt252 using LCG
pub fn hash_felt252(value: felt252) -> u32 {
    hash_u32(felt252_to_u32(value))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hash_u32() {
        let result1 = hash_u32(1);
        let result2 = hash_u32(1);
        assert(result1 == result2, 'Should be deterministic');
        
        let result3 = hash_u32(2);
        assert(result1 != result3, 'Different inputs should give different outputs');
    }

    #[test]
    fn test_hash_u32_pair() {
        let result1 = hash_u32_pair(1, 2);
        let result2 = hash_u32_pair(2, 1);
        assert(result1 != result2, 'Order should matter');
        
        let result3 = hash_u32_pair(1, 2);
        assert(result1 == result3, 'Should be deterministic');
    }

    #[test]
    fn test_hash_u32_triple() {
        let result1 = hash_u32_triple(1, 2, 3);
        let result2 = hash_u32_triple(1, 2, 3);
        assert(result1 == result2, 'Should be deterministic');
        
        let result3 = hash_u32_triple(3, 2, 1);
        assert(result1 != result3, 'Order should matter');
    }

    #[test]
    fn test_hash_u32_quad() {
        let result1 = hash_u32_quad(1, 2, 3, 4);
        let result2 = hash_u32_quad(1, 2, 3, 4);
        assert(result1 == result2, 'Should be deterministic');
        
        let result3 = hash_u32_quad(4, 3, 2, 1);
        assert(result1 != result3, 'Order should matter');
    }

    #[test]
    fn test_felt252_conversion() {
        let felt_val: felt252 = 0x12345678;
        let u32_val = felt252_to_u32(felt_val);
        assert(u32_val == 0x12345678, 'Should extract lower 32 bits');
        
        let hash_result = hash_felt252(felt_val);
        assert(hash_result != 0, 'Should produce non-zero hash');
    }
}