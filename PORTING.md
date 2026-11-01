# Porting

The behavior source is num-bigint 0.4.8. Java `BigInteger`, Go `math/big`, and Python `int` agree with it on the cases below, except where a note says otherwise. The checks in `tests/self_check.goose` are strings and bytes that crate prints.

## Names

`BigInt` is `Int`. `from_str` is `parse`. `from_str_radix` is `parse_radix`. `to_string` is `text`. `to_str_radix` is `text_radix`. `/` and `%` are `div` and `rem`. `div_floor` and `mod_floor` keep those names. `!` is `bitnot`. A failure is the trailing `bool`.

## What matches

`parse` accepts an optional sign, digits, and `_` between digits. `+10` is `10`. `1_000` is `1000`. `1_` is `1`. `-0` is `0`. An empty string, a bare sign, `++1`, `-+1`, a leading `_`, and a digit past the radix return false.

`div` truncates toward zero and `rem` takes the sign of the dividend. `-10 / 3` is `-3` remainder `-1`. `10 / -3` is `-3` remainder `1`. `div_floor` rounds toward negative infinity, so `10 / -3` is `-4` and the floor remainder is `-2`. That is Python's `//`.

Bitwise operations use an infinite two's complement. `bitnot` of 0 is `-1`. `-2 & -3` is `-4`. `shr` of a negative value rounds toward negative infinity, so `-5 >> 1` is `-3` and `-5 >> 100` is `-1`.

`pow` of any value to the power 0 is 1, including `0^0`. `modpow` follows `mod_floor`: the result lies in `[0, modulus)` when the modulus is positive, and in `(modulus, 0]` when it is negative. `-3^5 mod 13` is `4`. `3^5 mod -13` is `-4`. `modinv(271, 383)` is `106`. `gcd` is never negative. `sqrt(15)` is `3`.

Signed bytes match `to_signed_bytes_be`. `-128` is the single byte `0x80`. `128` is `0x00 0x80`.

## What is absent

There is no serde, no random integer, no `set_bit`, and no `cbrt` or `nth_root`. `from_radix_be` on raw digit bytes is not here. `parse_radix` reads text.

num-bigint panics on division by zero, on a negative shift, on a negative exponent or a zero modulus in `modpow`, and on the square root of a negative value. This package returns false in those cases.

`from_be` and `from_le` take `Sign`. `pack` still takes a `bool`. A cast is checked unless it is a digit just produced by division.

Multiplication is schoolbook and division is Knuth's Algorithm D. Neither is an FFT. A profile is the point at which a faster product is worth writing.

## Check

`goose tests/self_check.goose` from this directory printed `bigint ok` with no warnings. The strings were taken from num-bigint 0.4.8.
