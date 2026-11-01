<p align="center">
  <img src="logo.png" alt="A goose holding a long scroll" width="220">
</p>

<h1 align="center">goose-bigint</h1>

<p align="center">
  📜 Signed integers with no fixed width for <a href="https://github.com/aardappel/goose">Goose</a><br>
  <strong>0.1</strong> · <a href="LICENSE">Apache-2.0</a>
</p>

The same integer [num-bigint](https://docs.rs/num-bigint) 0.4 stores: a sign and a little-endian list of 32-bit limbs. Zero is an empty list. The value grows with the number, so it is not a `u256` and it is not the 96-bit decimal in [goose-decimal](https://github.com/Macho0x/goose-decimal).

Division toward zero matches Rust, Java `BigInteger`, and Go `big.Int`. `div_floor` matches Python's `//`. Bitwise operations use two's complement, so the complement of 0 is -1.

## Example

```goose
import bigint from "../bigint";

fn main() {
    let a, ok = bigint::parse("123456789012345678901234567890");
    if ok {
        let sq = bigint::mul(a, a);
        print(bigint::text(sq));
    }
}
```

That prints `15241578753238836750495351562536198787501905199875019052100`.

## Check

Install the Goose compiler, then from this directory:

```sh
goose tests/self_check.goose
```

A good run prints `bigint ok`.

## What you can call

| Function | What it does |
| --- | --- |
| `parse`, `parse_radix` | Decimal, or digits in base 2 through 36. `_` may separate digits |
| `text`, `text_radix` | The digits, with a leading `-` when the value is negative |
| `from_u64`, `from_i64`, `to_u64`, `to_i64` | Machine integers. A value that does not fit returns false |
| `from_be`, `from_le`, `to_be`, `to_le` | The magnitude as bytes. Zero is a single 0 byte |
| `from_signed_be`, `from_signed_le`, `to_signed_be`, `to_signed_le` | Two's complement bytes |
| `add`, `sub`, `mul` | The usual arithmetic |
| `div`, `rem`, `div_rem` | Toward zero. Division by zero returns false |
| `div_floor`, `mod_floor` | Toward negative infinity |
| `cmp`, `neg`, `abs`, `shl`, `shr` | Order, sign, and shifts. A negative shift count returns false |
| `bitand`, `bitor`, `bitxor`, `bitnot`, `bit`, `bits`, `trailing_zeros` | Two's complement bits |
| `pow`, `modpow`, `modinv`, `gcd`, `sqrt` | Powers, inverses, and the integer square root |

`PORTING.md` names the num-bigint pieces this package leaves out, and the places a panic in Rust is a `false` here.

## License

Apache-2.0. Free and open to everyone. The terms are in [LICENSE](LICENSE).
