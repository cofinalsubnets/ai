include!("../lib/bench.rs");

// bintrees -- the benchmark-game binary-trees (see bench/benches/bintrees.l): a
// GC-throughput / long-lived-survival workload. APPLES-TO-APPLES with ai's COPYING GC:
// the naive `Box<Tree>` malloc's + frees every node, rust's worst case for this churn.
// Instead we bump-allocate into ARENAS (children as indices) -- the long-lived tree in
// its own arena that survives the loop, the short-lived trees in a scratch arena CLEARED
// (bulk-reclaimed, like a minor GC) before each build. That's rust's memory model used
// well: bump to allocate, bulk-free to reclaim -- the same shape ai's collector has.
struct Arena {
    n: Vec<(i32, i32)>,
}

impl Arena {
    fn new(cap: usize) -> Self {
        Arena {
            n: Vec::with_capacity(cap),
        }
    }
    fn mk(&mut self, d: i64) -> i32 {
        if d < 1 {
            self.n.push((-1, -1)); // leaf
            (self.n.len() - 1) as i32
        } else {
            let l = self.mk(d - 1);
            let r = self.mk(d - 1);
            self.n.push((l, r));
            (self.n.len() - 1) as i32
        }
    }
    fn ck(&self, i: i32) -> i64 {
        let (l, r) = self.n[i as usize];
        if l < 0 {
            0
        } else {
            1 + self.ck(l) + self.ck(r)
        }
    }
}

fn bt_run(mn: i64, mx: i64) -> i64 {
    let mut scratch = Arena::new(1 << (mx + 1)); // reused for the short-lived trees
    let stretch = {
        scratch.n.clear();
        let r = scratch.mk(mx + 1);
        scratch.ck(r)
    };
    let mut long = Arena::new(1 << mx); // LONG-LIVED -- its own arena, survives the loop
    let long_root = long.mk(mx);
    let mut total: i64 = 0;
    let mut d = mn;
    while d <= mx {
        let n: i64 = 1 << (mx - d + mn);
        let mut s: i64 = 0;
        for _ in 0..n {
            scratch.n.clear(); // bulk-reclaim the previous short-lived tree
            let r = scratch.mk(d);
            s += scratch.ck(r);
        }
        total += s;
        d += 2;
    }
    stretch + long.ck(long_root) + total
}

fn main() {
    bench("bintrees", || bt_run(4, 14));
}
