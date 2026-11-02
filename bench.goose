// Times this package. One untimed batch, then batches until the window
// elapses. The sink keeps the call alive.
// Build with clang on the revision before a change, then again after:
//   goose build -o bigint-bench bench.goose --cc clang
//   ./bigint-bench
// Row names stay fixed. TinyCC (goose bench.goose) is not a timing result.
// ponytail: a fixed window, not a sampled harness. Rows under a microsecond
// move from run to run; lengthen the window before trusting them.

import os;
import bigint;

var big = bigint::zero();
var prod = bigint::zero();
var exp = bigint::zero();
var mod = bigint::zero();

fn mark(b: u8, ok: bool) -> u64 {
    if !ok { return 0; }
    let v: u64 = b;
    return v + 1;
}

fn limb(a: bigint::Int&) -> u64 {
    if a.w.len == 0 { return 1; }
    return mark((a.w[0] & 255) as! u8, true);
}

fn time_batch<F>(batch: i64, ms: i64) -> i64, u64 {
    var sink: u64 = 0;
    var k = 0;
    while k < batch {
        sink += F();
        k += 1;
    }
    var n: i64 = 0;
    var dt: i64 = 0;
    let end = clock_ns() + ms * 1000000;
    while true {
        let t0 = clock_ns();
        k = 0;
        while k < batch {
            sink += F();
            k += 1;
        }
        dt += clock_ns() - t0;
        n += batch;
        if clock_ns() >= end { break; }
    }
    return dt / n, sink;
}

fn row<F>(name: u8[:], batch: i64, ms: i64) -> u64 {
    let ns, part = time_batch(batch, ms, F);
    var line: u8[>..] = [];
    format(line, name);
    while line.len < 28 { line.push(' '); }
    format_int(line, ns, 10, 12, ' ');
    format(line, "\n");
    write_stdout(line);
    return part;
}

fn mul_row() -> u64 {
    var p = bigint::mul(big, big);
    return limb(p);
}

fn div_row() -> u64 {
    let q, ok = bigint::div(prod, big);
    if !ok { return 0; }
    return limb(q);
}

fn pow_row() -> u64 {
    let r, ok = bigint::modpow(big, exp, mod);
    if !ok { return 0; }
    return limb(r);
}

fn text_row() -> u64 {
    let t = bigint::text(prod);
    if t.len == 0 { return 0; }
    return mark(t[0], true);
}

fn ready() -> bool {
    let n, ok = bigint::parse("123456789012345678901234567890");
    if !ok { return false; }
    big = copy(n);
    prod = bigint::mul(big, big);
    if bigint::text(prod) != "15241578753238836750495351562536198787501905199875019052100" {
        return false;
    }
    let e, eok = bigint::parse("65537");
    let m, mok = bigint::parse("1000000007");
    if !eok || !mok { return false; }
    exp = copy(e);
    mod = copy(m);
    let q, qok = bigint::div(prod, big);
    return qok && bigint::text(q) == "123456789012345678901234567890";
}

fn ::main() {
    if !ready() { print("bench FAIL"); exit(1); }
    write_stdout("operation                       ns/call\n");
    var sink: u64 = 0;
    sink += row("mul 30 digits", 16, 200, mul_row);
    sink += row("div 60 digits", 16, 200, div_row);
    sink += row("modpow 65537", 4, 250, pow_row);
    sink += row("text 60 digits", 16, 200, text_row);
    var tail: u8[>..] = [];
    format(tail, "sink ");
    format(tail, sink);
    format(tail, "\n");
    write_stdout(tail);
}
