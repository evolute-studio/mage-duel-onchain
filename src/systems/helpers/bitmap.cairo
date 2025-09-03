// Core imports
use core::num::traits::Bounded;

// Internal imports
use evolute_duel::constants::bitmap::{
    TWO_POW_0, TWO_POW_1, TWO_POW_2, TWO_POW_3, TWO_POW_4, TWO_POW_5, TWO_POW_6, TWO_POW_7,
    TWO_POW_8, TWO_POW_9, TWO_POW_10, TWO_POW_11, TWO_POW_12, TWO_POW_13, TWO_POW_14, TWO_POW_15,
    TWO_POW_16, TWO_POW_17, TWO_POW_18, TWO_POW_19, TWO_POW_20, TWO_POW_21, TWO_POW_22, TWO_POW_23,
    TWO_POW_24, TWO_POW_25, TWO_POW_26, TWO_POW_27, TWO_POW_28, TWO_POW_29, TWO_POW_30, TWO_POW_31,
    TWO_POW_32, TWO_POW_33, TWO_POW_34, TWO_POW_35, TWO_POW_36, TWO_POW_37, TWO_POW_38, TWO_POW_39,
    TWO_POW_40, TWO_POW_41, TWO_POW_42, TWO_POW_43, TWO_POW_44, TWO_POW_45, TWO_POW_46, TWO_POW_47,
    TWO_POW_48, TWO_POW_49, TWO_POW_50, TWO_POW_51, TWO_POW_52, TWO_POW_53, TWO_POW_54, TWO_POW_55,
    TWO_POW_56, TWO_POW_57, TWO_POW_58, TWO_POW_59, TWO_POW_60, TWO_POW_61, TWO_POW_62, TWO_POW_63,
    TWO_POW_64, TWO_POW_65, TWO_POW_66, TWO_POW_67, TWO_POW_68, TWO_POW_69, TWO_POW_70, TWO_POW_71,
    TWO_POW_72, TWO_POW_73, TWO_POW_74, TWO_POW_75, TWO_POW_76, TWO_POW_77, TWO_POW_78, TWO_POW_79,
    TWO_POW_80, TWO_POW_81, TWO_POW_82, TWO_POW_83, TWO_POW_84, TWO_POW_85, TWO_POW_86, TWO_POW_87,
    TWO_POW_88, TWO_POW_89, TWO_POW_90, TWO_POW_91, TWO_POW_92, TWO_POW_93, TWO_POW_94, TWO_POW_95,
    TWO_POW_96, TWO_POW_97, TWO_POW_98, TWO_POW_99, TWO_POW_100, TWO_POW_101, TWO_POW_102, TWO_POW_103,
    TWO_POW_104, TWO_POW_105, TWO_POW_106, TWO_POW_107, TWO_POW_108, TWO_POW_109, TWO_POW_110, TWO_POW_111,
    TWO_POW_112, TWO_POW_113, TWO_POW_114, TWO_POW_115, TWO_POW_116, TWO_POW_117, TWO_POW_118, TWO_POW_119,
    TWO_POW_120, TWO_POW_121, TWO_POW_122, TWO_POW_123, TWO_POW_124, TWO_POW_125, TWO_POW_126, TWO_POW_127,
    TWO_POW_128, TWO_POW_129, TWO_POW_130, TWO_POW_131, TWO_POW_132, TWO_POW_133, TWO_POW_134, TWO_POW_135,
    TWO_POW_136, TWO_POW_137, TWO_POW_138, TWO_POW_139, TWO_POW_140, TWO_POW_141, TWO_POW_142, TWO_POW_143,
    TWO_POW_144, TWO_POW_145, TWO_POW_146, TWO_POW_147, TWO_POW_148, TWO_POW_149, TWO_POW_150, TWO_POW_151,
    TWO_POW_152, TWO_POW_153, TWO_POW_154, TWO_POW_155, TWO_POW_156, TWO_POW_157, TWO_POW_158, TWO_POW_159,
    TWO_POW_160, TWO_POW_161, TWO_POW_162, TWO_POW_163, TWO_POW_164, TWO_POW_165, TWO_POW_166, TWO_POW_167,
    TWO_POW_168, TWO_POW_169, TWO_POW_170, TWO_POW_171, TWO_POW_172, TWO_POW_173, TWO_POW_174, TWO_POW_175,
    TWO_POW_176, TWO_POW_177, TWO_POW_178, TWO_POW_179, TWO_POW_180, TWO_POW_181, TWO_POW_182, TWO_POW_183,
    TWO_POW_184, TWO_POW_185, TWO_POW_186, TWO_POW_187, TWO_POW_188, TWO_POW_189, TWO_POW_190, TWO_POW_191,
    TWO_POW_192, TWO_POW_193, TWO_POW_194, TWO_POW_195, TWO_POW_196, TWO_POW_197, TWO_POW_198, TWO_POW_199,
    TWO_POW_200, TWO_POW_201, TWO_POW_202, TWO_POW_203, TWO_POW_204, TWO_POW_205, TWO_POW_206, TWO_POW_207,
    TWO_POW_208, TWO_POW_209, TWO_POW_210, TWO_POW_211, TWO_POW_212, TWO_POW_213, TWO_POW_214, TWO_POW_215,
    TWO_POW_216, TWO_POW_217, TWO_POW_218, TWO_POW_219, TWO_POW_220, TWO_POW_221, TWO_POW_222, TWO_POW_223,
    TWO_POW_224, TWO_POW_225, TWO_POW_226, TWO_POW_227, TWO_POW_228, TWO_POW_229, TWO_POW_230, TWO_POW_231,
    TWO_POW_232, TWO_POW_233, TWO_POW_234, TWO_POW_235, TWO_POW_236, TWO_POW_237, TWO_POW_238, TWO_POW_239,
    TWO_POW_240, TWO_POW_241, TWO_POW_242, TWO_POW_243, TWO_POW_244, TWO_POW_245, TWO_POW_246, TWO_POW_247,
    TWO_POW_248, TWO_POW_249, TWO_POW_250, TWO_POW_251, TWO_POW_252
};

// Errors
mod errors {
    pub const INVALID_INDEX: felt252 = 'Bitmap: invalid index';
}

#[generate_trait]
pub impl Bitmap of BitmapTrait {
    #[inline(always)]
    fn get_bit_at(bitmap: u256, index: felt252) -> bool {
        let mask = Self::two_pow(index);
        bitmap & mask == mask
    }

    #[inline(always)]
    fn set_bit_at(bitmap: u256, index: felt252, value: bool) -> u256 {
        let mask = Self::two_pow(index);
        if value {
            bitmap | mask
        } else {
            bitmap & (Bounded::<u256>::MAX - mask)
        }
    }

    /// The index of the nearest significant bit to the index of the number,
    /// where the least significant bit is at index 0 and the most significant bit is at index 255
    /// # Arguments
    /// * `x` - The value for which to compute the most significant bit, must be greater than 0.
    /// * `s` - The index for which to start the search.
    /// # Returns
    /// * The index of the nearest significant bit
    #[inline(always)]
    fn nearest_significant_bit(x: u256, s: u8) -> Option<u8> {
        let lower_mask = Self::set_bit_at(0, (s + 1).into(), true) - 1;
        let lower = Self::most_significant_bit(x & lower_mask);
        let upper_mask = ~(lower_mask / 2);
        let upper = Self::least_significant_bit(x & upper_mask);
        match (lower, upper) {
            (
                Option::Some(l), Option::Some(u)
            ) => { 
                if s - l < u - s {
                    Option::Some(l)
                } else {
                    Option::Some(u)
                } 
            },
            (Option::Some(l), Option::None) => Option::Some(l),
            (Option::None, Option::Some(u)) => Option::Some(u),
            (Option::None, Option::None) => Option::None,
        }
    }

    /// The index of the most significant bit of the number,
    /// where the least significant bit is at index 0 and the most significant bit is at index 255
    /// Source: https://github.com/lambdaclass/yet-another-swap/blob/main/crates/yas_core/src/libraries/bit_math.cairo
    /// # Arguments
    /// * `x` - The value for which to compute the most significant bit, must be greater than 0.
    /// # Returns
    /// * The index of the most significant bit
    #[inline(always)]
    fn most_significant_bit(mut x: u256) -> Option<u8> {
        if x == 0 {
            return Option::None;
        }
        let mut r: u8 = 0;

        if x >= 0x100000000000000000000000000000000 {
            x /= 0x100000000000000000000000000000000;
            r += 128;
        }
        if x >= 0x10000000000000000 {
            x /= 0x10000000000000000;
            r += 64;
        }
        if x >= 0x100000000 {
            x /= 0x100000000;
            r += 32;
        }
        if x >= 0x10000 {
            x /= 0x10000;
            r += 16;
        }
        if x >= 0x100 {
            x /= 0x100;
            r += 8;
        }
        if x >= 0x10 {
            x /= 0x10;
            r += 4;
        }
        if x >= 0x4 {
            x /= 0x4;
            r += 2;
        }
        if x >= 0x2 {
            r += 1;
        }
        Option::Some(r)
    }

    /// The index of the least significant bit of the number,
    /// where the least significant bit is at index 0 and the most significant bit is at index 255
    /// Source: https://github.com/lambdaclass/yet-another-swap/blob/main/crates/yas_core/src/libraries/bit_math.cairo
    /// # Arguments
    /// * `x` - The value for which to compute the least significant bit, must be greater than 0.
    /// # Returns
    /// * The index of the least significant bit
    #[inline(always)]
    fn least_significant_bit(mut x: u256) -> Option<u8> {
        if x == 0 {
            return Option::None;
        }
        let mut r: u8 = 255;

        if (x & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) > 0 {
            r -= 128;
        } else {
            x /= 0x100000000000000000000000000000000;
        }
        if (x & 0xFFFFFFFFFFFFFFFF) > 0 {
            r -= 64;
        } else {
            x /= 0x10000000000000000;
        }
        if (x & 0xFFFFFFFF) > 0 {
            r -= 32;
        } else {
            x /= 0x100000000;
        }
        if (x & 0xFFFF) > 0 {
            r -= 16;
        } else {
            x /= 0x10000;
        }
        if (x & 0xFF) > 0 {
            r -= 8;
        } else {
            x /= 0x100;
        }
        if (x & 0xF) > 0 {
            r -= 4;
        } else {
            x /= 0x10;
        }
        if (x & 0x3) > 0 {
            r -= 2;
        } else {
            x /= 0x4;
        }
        if (x & 0x1) > 0 {
            r -= 1;
        }
        Option::Some(r)
    }

    #[inline(always)]
    fn two_pow(exponent: felt252) -> u256 {
        match exponent {
            0 => TWO_POW_0,
            1 => TWO_POW_1,
            2 => TWO_POW_2,
            3 => TWO_POW_3,
            4 => TWO_POW_4,
            5 => TWO_POW_5,
            6 => TWO_POW_6,
            7 => TWO_POW_7,
            8 => TWO_POW_8,
            9 => TWO_POW_9,
            10 => TWO_POW_10,
            11 => TWO_POW_11,
            12 => TWO_POW_12,
            13 => TWO_POW_13,
            14 => TWO_POW_14,
            15 => TWO_POW_15,
            16 => TWO_POW_16,
            17 => TWO_POW_17,
            18 => TWO_POW_18,
            19 => TWO_POW_19,
            20 => TWO_POW_20,
            21 => TWO_POW_21,
            22 => TWO_POW_22,
            23 => TWO_POW_23,
            24 => TWO_POW_24,
            25 => TWO_POW_25,
            26 => TWO_POW_26,
            27 => TWO_POW_27,
            28 => TWO_POW_28,
            29 => TWO_POW_29,
            30 => TWO_POW_30,
            31 => TWO_POW_31,
            32 => TWO_POW_32,
            33 => TWO_POW_33,
            34 => TWO_POW_34,
            35 => TWO_POW_35,
            36 => TWO_POW_36,
            37 => TWO_POW_37,
            38 => TWO_POW_38,
            39 => TWO_POW_39,
            40 => TWO_POW_40,
            41 => TWO_POW_41,
            42 => TWO_POW_42,
            43 => TWO_POW_43,
            44 => TWO_POW_44,
            45 => TWO_POW_45,
            46 => TWO_POW_46,
            47 => TWO_POW_47,
            48 => TWO_POW_48,
            49 => TWO_POW_49,
            50 => TWO_POW_50,
            51 => TWO_POW_51,
            52 => TWO_POW_52,
            53 => TWO_POW_53,
            54 => TWO_POW_54,
            55 => TWO_POW_55,
            56 => TWO_POW_56,
            57 => TWO_POW_57,
            58 => TWO_POW_58,
            59 => TWO_POW_59,
            60 => TWO_POW_60,
            61 => TWO_POW_61,
            62 => TWO_POW_62,
            63 => TWO_POW_63,
            64 => TWO_POW_64,
            65 => TWO_POW_65,
            66 => TWO_POW_66,
            67 => TWO_POW_67,
            68 => TWO_POW_68,
            69 => TWO_POW_69,
            70 => TWO_POW_70,
            71 => TWO_POW_71,
            72 => TWO_POW_72,
            73 => TWO_POW_73,
            74 => TWO_POW_74,
            75 => TWO_POW_75,
            76 => TWO_POW_76,
            77 => TWO_POW_77,
            78 => TWO_POW_78,
            79 => TWO_POW_79,
            80 => TWO_POW_80,
            81 => TWO_POW_81,
            82 => TWO_POW_82,
            83 => TWO_POW_83,
            84 => TWO_POW_84,
            85 => TWO_POW_85,
            86 => TWO_POW_86,
            87 => TWO_POW_87,
            88 => TWO_POW_88,
            89 => TWO_POW_89,
            90 => TWO_POW_90,
            91 => TWO_POW_91,
            92 => TWO_POW_92,
            93 => TWO_POW_93,
            94 => TWO_POW_94,
            95 => TWO_POW_95,
            96 => TWO_POW_96,
            97 => TWO_POW_97,
            98 => TWO_POW_98,
            99 => TWO_POW_99,
            100 => TWO_POW_100,
            101 => TWO_POW_101,
            102 => TWO_POW_102,
            103 => TWO_POW_103,
            104 => TWO_POW_104,
            105 => TWO_POW_105,
            106 => TWO_POW_106,
            107 => TWO_POW_107,
            108 => TWO_POW_108,
            109 => TWO_POW_109,
            110 => TWO_POW_110,
            111 => TWO_POW_111,
            112 => TWO_POW_112,
            113 => TWO_POW_113,
            114 => TWO_POW_114,
            115 => TWO_POW_115,
            116 => TWO_POW_116,
            117 => TWO_POW_117,
            118 => TWO_POW_118,
            119 => TWO_POW_119,
            120 => TWO_POW_120,
            121 => TWO_POW_121,
            122 => TWO_POW_122,
            123 => TWO_POW_123,
            124 => TWO_POW_124,
            125 => TWO_POW_125,
            126 => TWO_POW_126,
            127 => TWO_POW_127,
            128 => TWO_POW_128,
            129 => TWO_POW_129,
            130 => TWO_POW_130,
            131 => TWO_POW_131,
            132 => TWO_POW_132,
            133 => TWO_POW_133,
            134 => TWO_POW_134,
            135 => TWO_POW_135,
            136 => TWO_POW_136,
            137 => TWO_POW_137,
            138 => TWO_POW_138,
            139 => TWO_POW_139,
            140 => TWO_POW_140,
            141 => TWO_POW_141,
            142 => TWO_POW_142,
            143 => TWO_POW_143,
            144 => TWO_POW_144,
            145 => TWO_POW_145,
            146 => TWO_POW_146,
            147 => TWO_POW_147,
            148 => TWO_POW_148,
            149 => TWO_POW_149,
            150 => TWO_POW_150,
            151 => TWO_POW_151,
            152 => TWO_POW_152,
            153 => TWO_POW_153,
            154 => TWO_POW_154,
            155 => TWO_POW_155,
            156 => TWO_POW_156,
            157 => TWO_POW_157,
            158 => TWO_POW_158,
            159 => TWO_POW_159,
            160 => TWO_POW_160,
            161 => TWO_POW_161,
            162 => TWO_POW_162,
            163 => TWO_POW_163,
            164 => TWO_POW_164,
            165 => TWO_POW_165,
            166 => TWO_POW_166,
            167 => TWO_POW_167,
            168 => TWO_POW_168,
            169 => TWO_POW_169,
            170 => TWO_POW_170,
            171 => TWO_POW_171,
            172 => TWO_POW_172,
            173 => TWO_POW_173,
            174 => TWO_POW_174,
            175 => TWO_POW_175,
            176 => TWO_POW_176,
            177 => TWO_POW_177,
            178 => TWO_POW_178,
            179 => TWO_POW_179,
            180 => TWO_POW_180,
            181 => TWO_POW_181,
            182 => TWO_POW_182,
            183 => TWO_POW_183,
            184 => TWO_POW_184,
            185 => TWO_POW_185,
            186 => TWO_POW_186,
            187 => TWO_POW_187,
            188 => TWO_POW_188,
            189 => TWO_POW_189,
            190 => TWO_POW_190,
            191 => TWO_POW_191,
            192 => TWO_POW_192,
            193 => TWO_POW_193,
            194 => TWO_POW_194,
            195 => TWO_POW_195,
            196 => TWO_POW_196,
            197 => TWO_POW_197,
            198 => TWO_POW_198,
            199 => TWO_POW_199,
            200 => TWO_POW_200,
            201 => TWO_POW_201,
            202 => TWO_POW_202,
            203 => TWO_POW_203,
            204 => TWO_POW_204,
            205 => TWO_POW_205,
            206 => TWO_POW_206,
            207 => TWO_POW_207,
            208 => TWO_POW_208,
            209 => TWO_POW_209,
            210 => TWO_POW_210,
            211 => TWO_POW_211,
            212 => TWO_POW_212,
            213 => TWO_POW_213,
            214 => TWO_POW_214,
            215 => TWO_POW_215,
            216 => TWO_POW_216,
            217 => TWO_POW_217,
            218 => TWO_POW_218,
            219 => TWO_POW_219,
            220 => TWO_POW_220,
            221 => TWO_POW_221,
            222 => TWO_POW_222,
            223 => TWO_POW_223,
            224 => TWO_POW_224,
            225 => TWO_POW_225,
            226 => TWO_POW_226,
            227 => TWO_POW_227,
            228 => TWO_POW_228,
            229 => TWO_POW_229,
            230 => TWO_POW_230,
            231 => TWO_POW_231,
            232 => TWO_POW_232,
            233 => TWO_POW_233,
            234 => TWO_POW_234,
            235 => TWO_POW_235,
            236 => TWO_POW_236,
            237 => TWO_POW_237,
            238 => TWO_POW_238,
            239 => TWO_POW_239,
            240 => TWO_POW_240,
            241 => TWO_POW_241,
            242 => TWO_POW_242,
            243 => TWO_POW_243,
            244 => TWO_POW_244,
            245 => TWO_POW_245,
            246 => TWO_POW_246,
            247 => TWO_POW_247,
            248 => TWO_POW_248,
            249 => TWO_POW_249,
            250 => TWO_POW_250,
            251 => TWO_POW_251,
            252 => TWO_POW_252,
            _ => {
                panic!("Bitmap: invalid index");
                0
            },
        }
    }
}