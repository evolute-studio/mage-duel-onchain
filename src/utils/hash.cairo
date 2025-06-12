use core::poseidon::{PoseidonTrait};
use core::hash::HashStateTrait;
use core::sha256::compute_sha256_byte_array;

pub fn hash_values(values: Span<felt252>) -> felt252 {
    let hash = hash_values_with_sha256(values);
    println!("SHA256 hash: {:?}", hash);
    hash_sha256_to_felt252(hash.span())
}

pub fn hash_values_with_sha256(values: Span<felt252>) -> [u32; 8] {
     assert(values.len() > 0, 'hash_values() has no values!');
    let mut bytes_input: ByteArray = "";
    for value in values {
        let as_byte_array: ByteArray = format!("{}", *value);
        bytes_input.append(@as_byte_array);
    };
    println!("Input bytes: {:?}", bytes_input);
    let hash = compute_sha256_byte_array(@bytes_input);
    
    hash
}

pub fn hash_sha256_to_felt252(hash: Span<u32>) -> felt252 {
    assert!(hash.len() == 8, "hash_sha256_to_felt252() expects a SHA256 hash of 8 u32 values!");
    let mut state = PoseidonTrait::new();
    for element in hash {
        state = state.update((*element).into());
    };
    let result = state.finalize();
    assert(result != 0, 'hash_values() returned zero!');
    result
}

//----------------------------------------
// Unit  tests
//
#[cfg(test)]
mod unit {
    use super::{
        hash_values,
    };

    #[test]
    fn test_hash_values() {
        let h1: felt252 = hash_values([111].span());
        let h11: felt252 = hash_values([111, 111].span());
        let h12: felt252 = hash_values([111, 222].span());
        let h21: felt252 = hash_values([222, 111].span());
        let h123: felt252 = hash_values([111, 222, 333].span());
        let h1234: felt252 = hash_values([111, 222, 333, 444].span());
        assert_ne!(h1, 0, "h1");
        assert_eq!(h1, h11, "h1 == h11");
        assert_ne!(h1, h12, "h1 != h12");
        assert_ne!(h12, h123, "h12 != h123");
        assert_ne!(h123, h1234, "h3 != h4");
        assert_ne!(h12, h21, "h12 != h21");
    }

    #[test]
    fn test_rehash() {
        let h1: felt252 = hash_values([111].span());
        let h2: felt252 = hash_values([h1].span());
        let h3: felt252 = hash_values([h2].span());
        assert_ne!(h1, 0, "h1");
        assert_ne!(h1, h2, "h1 != h2");
        assert_ne!(h2, h3, "h2 != h3");
    }

    #[test]
    fn test_xor_hash() {
        let a: felt252 = 0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
        let b: felt252 = 0x4d07e40e93398ed3c76981e72dd1fd22557a78ce36c0515f679e27f0bb5bc5f;
        let aa: u256 = a.into();
        let bb: u256 = b.into();
        let a_b = aa ^ bb;
        let b_a = bb ^ aa;
        // xor hashes are EQUAL for (a,b) and (b,a)
        assert_eq!(a_b, b_a, "felt_to_u128");
    }
}
