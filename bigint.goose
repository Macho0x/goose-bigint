// A signed integer with no fixed width. Limbs are little-endian u32.
// Zero is an empty limb list and a clear sign. Division toward zero matches
// Rust num-bigint, Java BigInteger, and Go big.Int. div_floor matches
// Python's //. Bitwise ops use two's complement, so !0 is -1.
// A zero divisor, a negative shift, a negative square root, a non-invertible
// modinv, and a bad parse return false. Nothing here aborts.
// ponytail: schoolbook multiply and Knuth division. Karatsuba when a profile says so.

namespace bigint;

struct Int {
    neg: bool,
    w: u32[>..],
}

fn zero() -> Int {
    var w: u32[>..] = [];
    return Int { neg: false, w: w };
}

fn trim(w: u32[>..]&) {
    while w.len > 0 && w[w.len - 1] == 0 { w.pop(); }
}

fn pack(neg: bool, w: u32[>..]&) -> Int {
    trim(w);
    if w.len == 0 { return zero(); }
    var o: u32[>..] = [];
    o.append(w);
    return Int { neg: neg, w: o };
}

fn clone(a: Int&) -> Int {
    var w: u32[>..] = [];
    w.append(a.w);
    return Int { neg: a.neg, w: w };
}

fn is_zero(a: Int&) -> bool { return a.w.len == 0; }

fn mag_cmp(a: u32[:], b: u32[:]) -> i64 {
    if a.len < b.len { return -1; }
    if a.len > b.len { return 1; }
    var i = a.len;
    while i > 0 {
        i -= 1;
        if a[i] < b[i] { return -1; }
        if a[i] > b[i] { return 1; }
    }
    return 0;
}

fn mag_add(a: u32[:], b: u32[:]) -> u32[>..] {
    var o: u32[>..] = [];
    var carry: u64 = 0;
    let n = if a.len > b.len { a.len } else { b.len };
    for i in 0..n {
        var av: u64 = 0;
        var bv: u64 = 0;
        if i < a.len { av = a[i]; }
        if i < b.len { bv = b[i]; }
        let s = av + bv + carry;
        o.push((s & 0xffffffff) as! u32);
        carry = s >> 32;
    }
    if carry != 0 { o.push(carry as! u32); }
    return o;
}

fn mag_add_small(a: u32[:], v: u32) -> u32[>..] {
    var o: u32[>..] = [];
    var carry: u64 = v;
    for i in 0..a.len {
        let ai: u64 = a[i];
        let s = ai + carry;
        o.push((s & 0xffffffff) as! u32);
        carry = s >> 32;
    }
    if carry != 0 { o.push(carry as! u32); }
    trim(o);
    return o;
}

fn mag_sub(a: u32[:], b: u32[:]) -> u32[>..] {
    var o: u32[>..] = [];
    var borrow: u64 = 0;
    let base: u64 = 4294967296;
    for i in 0..a.len {
        let av: u64 = a[i];
        var bv: u64 = 0;
        if i < b.len { bv = b[i]; }
        let sub = bv + borrow;
        if av >= sub {
            o.push((av - sub) as! u32);
            borrow = 0;
        } else {
            o.push((av + base - sub) as! u32);
            borrow = 1;
        }
    }
    trim(o);
    return o;
}

fn mag_mul_small(a: u32[:], m: u32) -> u32[>..] {
    var o: u32[>..] = [];
    var carry: u64 = 0;
    let mm: u64 = m;
    for i in 0..a.len {
        let ai: u64 = a[i];
        let p = ai * mm + carry;
        o.push((p & 0xffffffff) as! u32);
        carry = p >> 32;
    }
    if carry != 0 { o.push(carry as! u32); }
    return o;
}

fn mag_mul(a: u32[:], b: u32[:]) -> u32[>..] {
    var acc: u32[>..] = [];
    if a.len == 0 || b.len == 0 { return acc; }
    let n = a.len + b.len;
    for i in 0..n { acc.push(0); }
    for i in 0..a.len {
        var carry: u64 = 0;
        for j in 0..b.len {
            let k = i + j;
            let ai: u64 = a[i];
            let bj: u64 = b[j];
            let ak: u64 = acc[k];
            let p = ai * bj + ak + carry;
            acc[k] = (p & 0xffffffff) as! u32;
            carry = p >> 32;
        }
        var k = i + b.len;
        while carry != 0 {
            let ak: u64 = acc[k];
            let s = ak + carry;
            acc[k] = (s & 0xffffffff) as! u32;
            carry = s >> 32;
            k += 1;
        }
    }
    trim(acc);
    return acc;
}

fn mag_shl(a: u32[:], n: i64) -> u32[>..] {
    var o: u32[>..] = [];
    if n == 0 {
        o.append(a);
        return o;
    }
    let limbs = n / 32;
    let sh = n % 32;
    for i in 0..limbs { o.push(0); }
    if sh == 0 {
        o.append(a);
        return o;
    }
    var carry: u64 = 0;
    let s: u64 = sh as u64;
    for i in 0..a.len {
        let ai: u64 = a[i];
        let cur = (ai << s) | carry;
        o.push((cur & 0xffffffff) as! u32);
        carry = cur >> 32;
    }
    if carry != 0 { o.push(carry as! u32); }
    return o;
}

fn mag_shr(a: u32[:], n: i64) -> u32[>..] {
    var o: u32[>..] = [];
    if n == 0 {
        o.append(a);
        return o;
    }
    let limbs = n / 32;
    if limbs >= a.len { return o; }
    let sh = n % 32;
    if sh == 0 {
        for i in limbs..a.len { o.push(a[i]); }
        return o;
    }
    let s: u64 = sh as u64;
    let gap: u64 = 32 - s;
    let count = a.len - limbs;
    for i in 0..count {
        let src = limbs + i;
        let ai: u64 = a[src];
        var cur = ai >> s;
        if src + 1 < a.len {
            let hi: u64 = a[src + 1];
            cur = cur | (hi << gap);
        }
        o.push((cur & 0xffffffff) as! u32);
    }
    trim(o);
    return o;
}

fn mag_tz(a: u32[:]) -> i64 {
    var n: i64 = 0;
    for i in 0..a.len {
        if a[i] == 0 {
            n += 32;
        } else {
            var x = a[i];
            while (x & 1) == 0 {
                x = x >> 1;
                n += 1;
            }
            return n;
        }
    }
    return n;
}

fn place_digit(q: u32[>..]&, at: i64, qhat: u64) {
    var carry = qhat;
    var i = at;
    while carry != 0 {
        if i == q.len { q.push(0); }
        let cur: u64 = q[i];
        let s = cur + carry;
        q[i] = (s & 0xffffffff) as! u32;
        carry = s >> 32;
        i += 1;
    }
}

fn mag_div(n: u32[:], d: u32[:]) -> u32[>..], u32[>..] {
    var q: u32[>..] = [];
    var r: u32[>..] = [];
    if d.len == 0 || mag_cmp(n, d) < 0 {
        r.append(n);
        return q, r;
    }
    if d.len == 1 {
        let div: u64 = d[0];
        for i in 0..n.len { q.push(0); }
        var rem: u64 = 0;
        var i = n.len;
        while i > 0 {
            i -= 1;
            let ni: u64 = n[i];
            let cur = (rem << 32) | ni;
            let qq = cur / div;
            q[i] = (qq & 0xffffffff) as! u32;
            rem = cur - qq * div;
        }
        trim(q);
        if rem != 0 { r.push(rem as! u32); }
        return q, r;
    }
    let top = d[d.len - 1];
    var shift: i64 = 0;
    var probe = top;
    while probe < 0x80000000 {
        probe = probe << 1;
        shift += 1;
    }
    var un = mag_shl(n, shift);
    var vn = mag_shl(d, shift);
    let nn = vn.len;
    let m = un.len - nn;
    un.push(0);
    for i in 0..(m + 1) { q.push(0); }
    let base: u64 = 4294967296;
    let vtop: u64 = vn[nn - 1];
    let vn2: u64 = vn[nn - 2];
    var j = m;
    while j >= 0 {
        let uj2: u64 = un[j + nn];
        let uj1: u64 = un[j + nn - 1];
        let num = (uj2 << 32) | uj1;
        var qhat = num / vtop;
        var rhat = num - qhat * vtop;
        let uj0: u64 = un[j + nn - 2];
        var fixing = true;
        while fixing {
            var over = false;
            if qhat >= base {
                over = true;
            } else {
                let rhs = (rhat << 32) + uj0;
                if qhat * vn2 > rhs { over = true; }
            }
            if !over {
                fixing = false;
            } else {
                qhat = qhat - 1;
                rhat = rhat + vtop;
                if rhat >= base { fixing = false; }
            }
        }
        var carry: u64 = 0;
        var borrow: u64 = 0;
        for i in 0..nn {
            let loq = qhat & 0xffffffff;
            let hiq = qhat >> 32;
            let mv: u64 = vn[i];
            let p0 = loq * mv + (carry & 0xffffffff);
            carry = hiq * mv + (carry >> 32) + (p0 >> 32);
            let prod = p0 & 0xffffffff;
            let cur: u64 = un[j + i];
            let need = prod + borrow;
            if cur >= need {
                un[j + i] = (cur - need) as! u32;
                borrow = 0;
            } else {
                un[j + i] = (cur + base - need) as! u32;
                borrow = 1;
            }
        }
        let cur: u64 = un[j + nn];
        let need = carry + borrow;
        if cur >= need {
            un[j + nn] = (cur - need) as! u32;
        } else {
            un[j + nn] = (cur + base - need) as! u32;
            var c: u64 = 0;
            for i in 0..nn {
                let s: u64 = un[j + i];
                let vi: u64 = vn[i];
                let sum = s + vi + c;
                un[j + i] = (sum & 0xffffffff) as! u32;
                c = sum >> 32;
            }
            let topv: u64 = un[j + nn];
            un[j + nn] = (topv + c) as! u32;
            qhat = qhat - 1;
        }
        place_digit(q, j, qhat);
        j -= 1;
    }
    var low: u32[>..] = [];
    for i in 0..nn { low.push(un[i]); }
    let rem = mag_shr(low, shift);
    trim(q);
    r.append(rem);
    trim(r);
    return q, r;
}

fn from_u64(v: u64) -> Int {
    var w: u32[>..] = [];
    if v == 0 { return Int { neg: false, w: w }; }
    w.push((v & 0xffffffff) as! u32);
    let hi = v >> 32;
    if hi != 0 { w.push(hi as! u32); }
    return Int { neg: false, w: w };
}

fn from_i64(v: i64) -> Int {
    if v >= 0 { return from_u64(v as u64); }
    var n = zero();
    if v == -9223372036854775808 {
        n = from_u64(v as u64);
    } else {
        n = from_u64((-v) as u64);
    }
    n.neg = true;
    return n;
}

fn to_u64(a: Int&) -> u64, bool {
    if a.neg { return 0, false; }
    if a.w.len == 0 { return 0, true; }
    if a.w.len == 1 { return a.w[0], true; }
    if a.w.len == 2 {
        let lo: u64 = a.w[0];
        let hi: u64 = a.w[1];
        return lo | (hi << 32), true;
    }
    return 0, false;
}

fn to_i64(a: Int&) -> i64, bool {
    if !a.neg {
        let u, ok = to_u64(a);
        let lim: u64 = 9223372036854775807;
        if !ok || u > lim { return 0, false; }
        return u as! i64, true;
    }
    let m = abs(a);
    let u, ok = to_u64(m);
    let lim: u64 = 9223372036854775808;
    if !ok || u > lim { return 0, false; }
    if u == lim { return -9223372036854775808, true; }
    return -(u as! i64), true;
}

fn add(a: Int&, b: Int&) -> Int {
    if is_zero(a) { return clone(b); }
    if is_zero(b) { return clone(a); }
    if a.neg == b.neg {
        let w = mag_add(a.w, b.w);
        return Int { neg: a.neg, w: w };
    }
    let ord = mag_cmp(a.w, b.w);
    if ord == 0 { return zero(); }
    if ord > 0 {
        let w = mag_sub(a.w, b.w);
        return pack(a.neg, w);
    }
    let w = mag_sub(b.w, a.w);
    return pack(b.neg, w);
}

fn neg(a: Int&) -> Int {
    if is_zero(a) { return zero(); }
    var c = clone(a);
    c.neg = !c.neg;
    return c;
}

fn abs(a: Int&) -> Int {
    var c = clone(a);
    c.neg = false;
    return c;
}

fn sub(a: Int&, b: Int&) -> Int {
    var nb = clone(b);
    if nb.w.len != 0 { nb.neg = !nb.neg; }
    return add(a, nb);
}

fn mul(a: Int&, b: Int&) -> Int {
    if is_zero(a) || is_zero(b) { return zero(); }
    let w = mag_mul(a.w, b.w);
    return Int { neg: a.neg != b.neg, w: w };
}

fn div_rem(a: Int&, b: Int&) -> Int, Int, bool {
    if is_zero(b) { return zero(), zero(), false; }
    let q, r = mag_div(a.w, b.w);
    var quot = pack(false, q);
    var rem = pack(false, r);
    if !is_zero(quot) && a.neg != b.neg { quot.neg = true; }
    if !is_zero(rem) && a.neg { rem.neg = true; }
    return quot, rem, true;
}

fn div(a: Int&, b: Int&) -> Int, bool {
    let q, r, ok = div_rem(a, b);
    return q, ok;
}

fn rem(a: Int&, b: Int&) -> Int, bool {
    let q, r, ok = div_rem(a, b);
    return r, ok;
}

fn div_floor(a: Int&, b: Int&) -> Int, bool {
    let q, r, ok = div_rem(a, b);
    if !ok { return zero(), false; }
    if is_zero(r) || a.neg == b.neg { return q, true; }
    let one = from_u64(1);
    let nq = sub(q, one);
    return nq, true;
}

fn mod_floor(a: Int&, b: Int&) -> Int, bool {
    let q, ok = div_floor(a, b);
    if !ok { return zero(), false; }
    let prod = mul(q, b);
    return sub(a, prod), true;
}

fn cmp(a: Int&, b: Int&) -> i64 {
    if is_zero(a) && is_zero(b) { return 0; }
    if a.neg != b.neg {
        if a.neg { return -1; }
        return 1;
    }
    var c = mag_cmp(a.w, b.w);
    if a.neg { c = -c; }
    return c;
}

fn shl(a: Int&, n: i64) -> Int, bool {
    if n < 0 { return zero(), false; }
    if is_zero(a) || n == 0 { return clone(a), true; }
    let w = mag_shl(a.w, n);
    return Int { neg: a.neg, w: w }, true;
}

fn shr(a: Int&, n: i64) -> Int, bool {
    if n < 0 { return zero(), false; }
    if n == 0 { return clone(a), true; }
    if is_zero(a) { return zero(), true; }
    if !a.neg {
        let w = mag_shr(a.w, n);
        return pack(false, w), true;
    }
    let zeros = mag_tz(a.w);
    var w = mag_shr(a.w, n);
    if zeros < n {
        let bumped = mag_add_small(w, 1);
        w = copy(bumped);
    }
    return pack(true, w), true;
}

fn tc(a: Int&, n: i64) -> u32[>..] {
    var o: u32[>..] = [];
    if !a.neg {
        for i in 0..n {
            if i < a.w.len { o.push(a.w[i]); } else { o.push(0); }
        }
        return o;
    }
    var carry: u64 = 1;
    for i in 0..n {
        var limb: u64 = 0;
        if i < a.w.len { limb = a.w[i]; }
        let s = (limb ^ 0xffffffff) + carry;
        o.push((s & 0xffffffff) as! u32);
        carry = s >> 32;
    }
    return o;
}

fn from_tc(w: u32[:]) -> Int {
    if w.len == 0 { return zero(); }
    let sign = (w[w.len - 1] & 0x80000000) != 0;
    if !sign {
        var o: u32[>..] = [];
        o.append(w);
        return pack(false, o);
    }
    var o: u32[>..] = [];
    var carry: u64 = 1;
    for i in 0..w.len {
        let inv: u64 = w[i] ^ 0xffffffff;
        let s = inv + carry;
        o.push((s & 0xffffffff) as! u32);
        carry = s >> 32;
    }
    return pack(true, o);
}

fn bit_width(a: Int&, b: Int&) -> i64 {
    if a.w.len > b.w.len { return a.w.len + 1; }
    return b.w.len + 1;
}

fn bitand(a: Int&, b: Int&) -> Int {
    let n = bit_width(a, b);
    let aw = tc(a, n);
    let bw = tc(b, n);
    var o: u32[>..] = [];
    for i in 0..n { o.push(aw[i] & bw[i]); }
    return from_tc(o);
}

fn bitor(a: Int&, b: Int&) -> Int {
    let n = bit_width(a, b);
    let aw = tc(a, n);
    let bw = tc(b, n);
    var o: u32[>..] = [];
    for i in 0..n { o.push(aw[i] | bw[i]); }
    return from_tc(o);
}

fn bitxor(a: Int&, b: Int&) -> Int {
    let n = bit_width(a, b);
    let aw = tc(a, n);
    let bw = tc(b, n);
    var o: u32[>..] = [];
    for i in 0..n { o.push(aw[i] ^ bw[i]); }
    return from_tc(o);
}

fn bitnot(a: Int&) -> Int {
    if is_zero(a) { return from_i64(-1); }
    if a.neg {
        let w = mag_sub(a.w, from_u64(1).w);
        return pack(false, w);
    }
    let w = mag_add_small(a.w, 1);
    return pack(true, w);
}

fn bits(a: Int&) -> u64 {
    if a.w.len == 0 { return 0; }
    var x = a.w[a.w.len - 1];
    var width: i64 = 0;
    while x > 0 {
        x = x >> 1;
        width += 1;
    }
    let lower = (a.w.len - 1) * 32;
    return (lower + width) as u64;
}

fn bit(a: Int&, i: i64) -> bool {
    if i < 0 { return false; }
    if !a.neg {
        let limb = i / 32;
        if limb >= a.w.len { return false; }
        let sh: u64 = (i % 32) as u64;
        return ((a.w[limb] >> sh) & 1) == 1;
    }
    let total = a.w.len * 32;
    if i >= total { return true; }
    let tz = mag_tz(a.w);
    if i < tz { return false; }
    if i == tz { return true; }
    let limb = i / 32;
    let sh: u64 = (i % 32) as u64;
    let on = ((a.w[limb] >> sh) & 1) == 1;
    return !on;
}

fn trailing_zeros(a: Int&) -> u64, bool {
    if is_zero(a) { return 0, false; }
    return mag_tz(a.w) as u64, true;
}

fn odd(a: Int&) -> bool {
    if a.w.len == 0 { return false; }
    return (a.w[0] & 1) == 1;
}

fn pow(a: Int&, exp: u64) -> Int {
    var result = from_u64(1);
    if exp == 0 { return result; }
    var base = clone(a);
    var e = exp;
    while e != 0 {
        if (e & 1) == 1 {
            let n = mul(result, base);
            result = copy(n);
        }
        e = e >> 1;
        if e != 0 {
            let n = mul(base, base);
            base = copy(n);
        }
    }
    return result;
}

fn modpow(base: Int&, exp: Int&, modulus: Int&) -> Int, bool {
    if exp.neg || is_zero(modulus) { return zero(), false; }
    let mod = abs(modulus);
    var result = from_u64(1);
    let ab = abs(base);
    let rb, rok = rem(ab, mod);
    if !rok { return zero(), false; }
    var b = rb;
    var e = clone(exp);
    while !is_zero(e) {
        if odd(e) {
            let p = mul(result, b);
            let rr, ok = rem(p, mod);
            if !ok { return zero(), false; }
            result = copy(rr);
        }
        let half, hok = shr(e, 1);
        if !hok { return zero(), false; }
        if !is_zero(half) {
            let sq = mul(b, b);
            let rr, ok = rem(sq, mod);
            if !ok { return zero(), false; }
            b = copy(rr);
        }
        e = copy(half);
    }
    if is_zero(result) { return zero(), true; }
    let base_odd = base.neg && odd(exp);
    if !base_odd && !modulus.neg { return clone(result), true; }
    if base_odd && modulus.neg {
        result.neg = true;
        return clone(result), true;
    }
    let gap = sub(mod, result);
    if modulus.neg {
        let flipped = neg(gap);
        return flipped, true;
    }
    return clone(gap), true;
}

fn gcd(a: Int&, b: Int&) -> Int {
    var x = abs(a);
    var y = abs(b);
    while !is_zero(y) {
        let r, ok = rem(x, y);
        if !ok { return x; }
        x = copy(y);
        y = copy(r);
    }
    return x;
}

fn modinv(a: Int&, m: Int&) -> Int, bool {
    if is_zero(m) { return zero(), false; }
    var r0 = clone(a);
    var r1 = clone(m);
    var s0 = from_u64(1);
    var s1 = zero();
    while !is_zero(r1) {
        let q, ok = div(r0, r1);
        if !ok { return zero(), false; }
        let prod = mul(q, r1);
        let r = sub(r0, prod);
        let sp = mul(q, s1);
        let ns = sub(s0, sp);
        r0 = copy(r1);
        r1 = copy(r);
        s0 = copy(s1);
        s1 = copy(ns);
    }
    if r0.w.len != 1 || r0.w[0] != 1 { return zero(), false; }
    if r0.neg {
        let flipped = neg(s0);
        s0 = copy(flipped);
    }
    return mod_floor(s0, m);
}

fn sqrt(a: Int&) -> Int, bool {
    if a.neg { return zero(), false; }
    if is_zero(a) { return zero(), true; }
    var x = clone(a);
    var going = true;
    while going {
        let q, ok = div(a, x);
        if !ok { return zero(), false; }
        let s = add(x, q);
        let n, nok = shr(s, 1);
        if !nok { return zero(), false; }
        if cmp(n, x) >= 0 {
            going = false;
        } else {
            x = copy(n);
        }
    }
    return x, true;
}

fn digit(c: u8) -> i64, bool {
    if c >= '0' && c <= '9' { return c - '0', true; }
    if c >= 'a' && c <= 'z' { return c - 'a' + 10, true; }
    if c >= 'A' && c <= 'Z' { return c - 'A' + 10, true; }
    return 0, false;
}

fn parse_radix(s: u8[:], radix: i64) -> Int, bool {
    if radix < 2 || radix > 36 || s.len == 0 { return zero(), false; }
    var i: i64 = 0;
    var neg = false;
    if s[0] == '-' {
        neg = true;
        i = 1;
        if i >= s.len || s[i] == '+' { return zero(), false; }
    }
    if i < s.len && s[i] == '+' {
        i += 1;
        if i >= s.len || s[i] == '+' { return zero(), false; }
    }
    if i >= s.len || s[i] == '_' { return zero(), false; }
    var w: u32[>..] = [];
    var saw = false;
    let rad: u32 = radix as! u32;
    while i < s.len {
        let c = s[i];
        i += 1;
        if c == '_' { continue; }
        let d, ok = digit(c);
        if !ok || d >= radix { return zero(), false; }
        let grown = mag_mul_small(w, rad);
        let added = mag_add_small(grown, d as! u32);
        w = copy(added);
        saw = true;
    }
    if !saw { return zero(), false; }
    return pack(neg, w), true;
}

fn parse(s: u8[:]) -> Int, bool { return parse_radix(s, 10); }

fn text_radix(a: Int&, radix: i64) -> u8[>..], bool {
    var out: u8[>..] = [];
    if radix < 2 || radix > 36 { return out, false; }
    if is_zero(a) {
        out.push('0');
        return out, true;
    }
    var w: u32[>..] = [];
    w.append(a.w);
    var digs: u8[>..] = [];
    let rad: u32 = radix as! u32;
    while w.len != 0 {
        let q, rem = mag_div(w, from_u64(rad).w);
        var r: u32 = 0;
        if rem.len != 0 { r = rem[0]; }
        var ch: u8 = '0' + (r as! u8);
        if r >= 10 { ch = 'a' + ((r - 10) as! u8); }
        digs.push(ch);
        w = copy(q);
    }
    if a.neg { out.push('-'); }
    var i = digs.len;
    while i > 0 {
        i -= 1;
        out.push(digs[i]);
    }
    return out, true;
}

fn text(a: Int&) -> u8[>..] {
    let s, ok = text_radix(a, 10);
    return s;
}

fn from_be(neg: bool, bytes: u8[:]) -> Int {
    var w: u32[>..] = [];
    var acc: u64 = 0;
    var shift: u64 = 0;
    var i = bytes.len;
    while i > 0 {
        i -= 1;
        let b: u64 = bytes[i];
        acc = acc | (b << shift);
        shift += 8;
        if shift == 32 {
            w.push((acc & 0xffffffff) as! u32);
            acc = 0;
            shift = 0;
        }
    }
    if shift != 0 { w.push(acc as! u32); }
    return pack(neg, w);
}

fn from_le(neg: bool, bytes: u8[:]) -> Int {
    var w: u32[>..] = [];
    var acc: u64 = 0;
    var shift: u64 = 0;
    for i in 0..bytes.len {
        let b: u64 = bytes[i];
        acc = acc | (b << shift);
        shift += 8;
        if shift == 32 {
            w.push((acc & 0xffffffff) as! u32);
            acc = 0;
            shift = 0;
        }
    }
    if shift != 0 { w.push(acc as! u32); }
    return pack(neg, w);
}

fn to_be(a: Int&) -> u8[>..] {
    var o: u8[>..] = [];
    if a.w.len == 0 {
        o.push(0);
        return o;
    }
    var started = false;
    var i = a.w.len;
    while i > 0 {
        i -= 1;
        let limb = a.w[i];
        var s: i64 = 24;
        while s >= 0 {
            let b: u8 = ((limb >> (s as u64)) & 0xff) as! u8;
            if started || b != 0 {
                started = true;
                o.push(b);
            }
            s -= 8;
        }
    }
    if !started { o.push(0); }
    return o;
}

fn to_le(a: Int&) -> u8[>..] {
    let be = to_be(a);
    var o: u8[>..] = [];
    var i = be.len;
    while i > 0 {
        i -= 1;
        o.push(be[i]);
    }
    return o;
}

fn twos_be(b: u8[>..]&) {
    var carry: u64 = 1;
    var i = b.len;
    while i > 0 {
        i -= 1;
        let bv: u64 = b[i] ^ 0xff;
        let s = bv + carry;
        b[i] = (s & 0xff) as! u8;
        carry = s >> 8;
    }
}

fn twos_le(b: u8[>..]&) {
    var carry: u64 = 1;
    for i in 0..b.len {
        let bv: u64 = b[i] ^ 0xff;
        let s = bv + carry;
        b[i] = (s & 0xff) as! u8;
        carry = s >> 8;
    }
}

fn high_byte_only(b: u8[:], at: i64, neg: bool) -> bool {
    if b[at] != 0x80 || !neg { return false; }
    for i in 0..b.len {
        if i != at && b[i] != 0 { return false; }
    }
    return true;
}

fn to_signed_be(a: Int&) -> u8[>..] {
    var bytes = to_be(a);
    if bytes[0] > 0x7f && !high_byte_only(bytes, 0, a.neg) {
        var extended: u8[>..] = [];
        extended.push(0);
        extended.append(bytes);
        bytes = copy(extended);
    }
    if a.neg { twos_be(bytes); }
    return bytes;
}

fn to_signed_le(a: Int&) -> u8[>..] {
    var bytes = to_le(a);
    let last = bytes.len - 1;
    if bytes[last] > 0x7f && !high_byte_only(bytes, last, a.neg) {
        bytes.push(0);
    }
    if a.neg { twos_le(bytes); }
    return bytes;
}

fn from_signed_be(bytes: u8[:]) -> Int {
    if bytes.len == 0 { return zero(); }
    if bytes[0] <= 0x7f { return from_be(false, bytes); }
    var copyb: u8[>..] = [];
    copyb.append(bytes);
    twos_be(copyb);
    return from_be(true, copyb);
}

fn from_signed_le(bytes: u8[:]) -> Int {
    if bytes.len == 0 { return zero(); }
    if bytes[bytes.len - 1] <= 0x7f { return from_le(false, bytes); }
    var copyb: u8[>..] = [];
    copyb.append(bytes);
    twos_le(copyb);
    return from_le(true, copyb);
}

fn ::main() {
    print("goose tests/self_check.goose");
}
