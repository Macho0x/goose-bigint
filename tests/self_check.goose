import bigint from "..";
import os;

fn fail(why: u8[:]) {
    write_stdout(why);
    write_stdout("\n");
    exit(1);
}

fn need(got: u8[:], want: u8[:], why: u8[:]) {
    if got != want { fail(why); }
}

fn show(s: u8[:]) -> u8[>..] {
    let n, ok = bigint::parse(s);
    if !ok { fail(s); }
    return bigint::text(n);
}

fn must_parse(s: u8[:]) -> bigint::Int {
    let n, ok = bigint::parse(s);
    if !ok { fail(s); }
    return n;
}

fn ::main() {
    let z = bigint::zero();
    need(bigint::text(z), "0", "0");
    need(show("0"), "0", "p0");
    need(show("-0"), "0", "-0");
    need(show("+10"), "10", "+10");
    need(show("1_000"), "1000", "1_000");
    need(show("-42"), "-42", "-42");
    need(show("00"), "0", "00");
    need(show("1_"), "1", "1_");

    let e, eok = bigint::parse("");
    if eok { fail("empty"); }
    let p1, p1ok = bigint::parse("+");
    if p1ok { fail("plus"); }
    let m, mok = bigint::parse("-");
    if mok { fail("minus"); }
    let pp, ppok = bigint::parse("++1");
    if ppok { fail("++"); }
    let mp, mpok = bigint::parse("-+1");
    if mpok { fail("-+"); }
    let us, usok = bigint::parse("_1");
    if usok { fail("_1"); }
    let bad, badok = bigint::parse("12a");
    if badok { fail("12a"); }

    let hx, hok = bigint::parse_radix("ff", 16);
    if !hok { fail("hex"); }
    need(bigint::text(hx), "255", "ff");
    let hn, hnok = bigint::parse_radix("-FF", 16);
    if !hnok { fail("hexneg"); }
    need(bigint::text(hn), "-255", "-FF");
    let hg, hgok = bigint::parse_radix("G", 16);
    if hgok { fail("G"); }
    let hr, hrok = bigint::parse_radix("10", 1);
    if hrok { fail("radix"); }

    let one = bigint::from_i64(-1);
    let not0 = bigint::bitnot(z);
    need(bigint::text(not0), "-1", "!0");
    let not1 = bigint::bitnot(one);
    need(bigint::text(not1), "0", "!-1");
    let five = bigint::from_i64(5);
    let not5 = bigint::bitnot(five);
    need(bigint::text(not5), "-6", "!5");

    let m1 = bigint::from_i64(-1);
    let m2 = bigint::from_i64(-2);
    let m3 = bigint::from_i64(-3);
    let m4 = bigint::from_i64(-4);
    let m5 = bigint::from_i64(-5);
    let three = bigint::from_i64(3);
    let n10 = bigint::from_i64(-10);
    let p10 = bigint::from_i64(10);
    let and1 = bigint::bitand(m1, five);
    need(bigint::text(and1), "5", "and");
    let and2 = bigint::bitand(m2, m3);
    need(bigint::text(and2), "-4", "and2");
    let oneu = bigint::from_i64(1);
    let or1 = bigint::bitor(oneu, m4);
    need(bigint::text(or1), "-3", "or");
    let xor1 = bigint::bitxor(five, m3);
    need(bigint::text(xor1), "-8", "xor");
    let xor2 = bigint::bitxor(m5, m3);
    need(bigint::text(xor2), "6", "xor2");

    let sh, shok = bigint::shl(m5, 1);
    if !shok { fail("shl"); }
    need(bigint::text(sh), "-10", "shl");
    let sr, srok = bigint::shr(m5, 1);
    if !srok { fail("shr"); }
    need(bigint::text(sr), "-3", "shr");
    let sr4, sr4ok = bigint::shr(m4, 1);
    if !sr4ok { fail("shr4"); }
    need(bigint::text(sr4), "-2", "shr4");
    let sr3, sr3ok = bigint::shr(m3, 1);
    if !sr3ok { fail("shr3"); }
    need(bigint::text(sr3), "-2", "shr3");
    let srb, srbok = bigint::shr(m5, 100);
    if !srbok { fail("shrbig"); }
    need(bigint::text(srb), "-1", "shrbig");
    let badsh, badshok = bigint::shl(five, -1);
    if badshok { fail("negshl"); }

    let p00 = bigint::pow(z, 0);
    need(bigint::text(p00), "1", "0^0");
    let pow10 = bigint::pow(m2, 10);
    need(bigint::text(pow10), "1024", "pow");
    let p3 = bigint::pow(m2, 3);
    need(bigint::text(p3), "-8", "pow3");

    let q, r, ok = bigint::div_rem(n10, three);
    if !ok { fail("div"); }
    need(bigint::text(q), "-3", "divq");
    need(bigint::text(r), "-1", "divr");
    let q2, r2, ok2 = bigint::div_rem(p10, m3);
    if !ok2 { fail("div2"); }
    need(bigint::text(q2), "-3", "div2q");
    need(bigint::text(r2), "1", "div2r");
    let q3, r3, ok3 = bigint::div_rem(n10, m3);
    if !ok3 { fail("div3"); }
    need(bigint::text(q3), "3", "div3q");
    need(bigint::text(r3), "-1", "div3r");
    let zd, zdok = bigint::div(p10, z);
    if zdok { fail("div0"); }

    let fq, fok = bigint::div_floor(p10, m3);
    if !fok { fail("floor"); }
    need(bigint::text(fq), "-4", "floorq");
    let fr, frok = bigint::mod_floor(p10, m3);
    if !frok { fail("floorm"); }
    need(bigint::text(fr), "-2", "floorr");
    let fq2, f2ok = bigint::div_floor(n10, three);
    if !f2ok { fail("floor2"); }
    need(bigint::text(fq2), "-4", "floor2q");
    let fr2, fr2ok = bigint::mod_floor(n10, three);
    if !fr2ok { fail("floor2m"); }
    need(bigint::text(fr2), "2", "floor2r");

    let neg15 = bigint::from_i64(-15);
    let pos25 = bigint::from_i64(25);
    let g1 = bigint::gcd(neg15, pos25);
    need(bigint::text(g1), "5", "gcd");
    let g0 = bigint::gcd(z, z);
    need(bigint::text(g0), "0", "gcd0");
    let g4 = bigint::gcd(z, m4);
    need(bigint::text(g4), "4", "gcd1");

    let mod13 = bigint::from_i64(13);
    let mpw, mpwok = bigint::modpow(m3, five, mod13);
    if !mpwok { fail("modpow"); }
    need(bigint::text(mpw), "4", "modpow");
    let neg13 = bigint::from_i64(-13);
    let mpn, mpnok = bigint::modpow(three, five, neg13);
    if !mpnok { fail("modpown"); }
    need(bigint::text(mpn), "-4", "modpown");
    let badexp, badexpok = bigint::modpow(three, m1, five);
    if badexpok { fail("negexp"); }

    let a271 = bigint::from_i64(271);
    let m383 = bigint::from_i64(383);
    let inv, invok = bigint::modinv(a271, m383);
    if !invok { fail("inv"); }
    need(bigint::text(inv), "106", "inv");
    let two = bigint::from_i64(2);
    let inv0, inv0ok = bigint::modinv(two, m4);
    if inv0ok { fail("inv0"); }

    let n15 = bigint::from_i64(15);
    let sq, sqok = bigint::sqrt(n15);
    if !sqok { fail("sqrt"); }
    need(bigint::text(sq), "3", "sqrt");
    let sq0, sq0ok = bigint::sqrt(z);
    if !sq0ok { fail("sqrt0"); }
    need(bigint::text(sq0), "0", "sqrt0");
    let n16 = bigint::from_i64(16);
    let sq1, sq1ok = bigint::sqrt(n16);
    if !sq1ok { fail("sqrt1"); }
    need(bigint::text(sq1), "4", "sqrt1");
    let sqn, sqnok = bigint::sqrt(m1);
    if sqnok { fail("sqrtneg"); }

    let n255 = bigint::from_i64(255);
    if bigint::bits(n255) != 8 { fail("bits"); }
    if bigint::bits(z) != 0 { fail("bits0"); }
    if bigint::bits(m1) != 1 { fail("bits-1"); }
    let n12 = bigint::from_i64(12);
    let tz, tzok = bigint::trailing_zeros(n12);
    if !tzok || tz != 2 { fail("tz"); }
    let tz0, tz0ok = bigint::trailing_zeros(z);
    if tz0ok { fail("tz0"); }
    if !bigint::bit(m5, 0) || !bigint::bit(m5, 1) || bigint::bit(m5, 2) { fail("bit"); }

    var b80: u8[] = [0x80];
    let sbe = bigint::from_signed_be(b80);
    need(bigint::text(sbe), "-128", "sbe");
    let n128 = bigint::from_i64(-128);
    if bigint::to_signed_be(n128) != b80 { fail("sbe3"); }
    var b7f: u8[] = [0x7f];
    let sbe2 = bigint::from_signed_be(b7f);
    need(bigint::text(sbe2), "127", "sbe2");
    let n127 = bigint::from_i64(127);
    if bigint::to_signed_be(n127) != b7f { fail("sbe2b"); }
    var b128: u8[] = [0, 128];
    let npos = bigint::from_i64(128);
    if bigint::to_signed_be(npos) != b128 { fail("sbe4"); }
    var bz: u8[] = [0];
    if bigint::to_be(z) != bz { fail("be0"); }
    var b256: u8[] = [1, 0];
    let n256 = bigint::from_i64(256);
    if bigint::to_be(n256) != b256 { fail("be1"); }
    var l256: u8[] = [0, 1];
    if bigint::to_le(n256) != l256 { fail("le1"); }
    let neg256 = bigint::from_be(true, b256);
    need(bigint::text(neg256), "-256", "frombe");

    let hi = bigint::from_u64(4294967295);
    let add1 = bigint::add(hi, oneu);
    need(bigint::text(add1), "4294967296", "add");
    let sub1 = bigint::sub(z, oneu);
    need(bigint::text(sub1), "-1", "sub");
    let min = bigint::from_i64(-9223372036854775808);
    need(bigint::text(min), "-9223372036854775808", "i64min");
    let back, backok = bigint::to_i64(min);
    if !backok || back != -9223372036854775808 { fail("toi64"); }

    let big = must_parse("123456789012345678901234567890");
    let prod = bigint::mul(big, big);
    need(bigint::text(prod), "15241578753238836750495351562536198787501905199875019052100", "mul");
    let qq, qqok = bigint::div(prod, big);
    if !qqok { fail("divbig"); }
    need(bigint::text(qq), "123456789012345678901234567890", "divbig");

    let hxtext, hxok = bigint::text_radix(hx, 16);
    if !hxok { fail("text16"); }
    need(hxtext, "ff", "text16");

    print("bigint ok");
}
