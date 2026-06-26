include!("../lib/bench.rs");

// binary-trees allocation/GC stress (see bench/benches/tree.l). checksum = 2^D-1.
// APPLES-TO-APPLES with ai's COPYING GC (which bump-allocates and bulk-reclaims dead
// nodes): the naive `Box<Tree>` is a malloc + an individual `drop` (free) PER NODE --
// rust's worst case for ephemeral tiny-object churn, and the only reason a GC'd ai/go
// "win" it. So we use a bump ARENA -- nodes pushed into a pre-sized Vec, children held
// as indices, the whole arena bulk-freed at the end -- rust's memory model used WELL, the
// same bump-then-bulk-reclaim shape ai's collector has (~10x the Box version; lands ahead).
struct Arena {
    n: Vec<(i32, i32)>,
}

impl Arena {
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

fn main() {
    bench("tree", || {
        let mut a = Arena {
            n: Vec::with_capacity(1 << 17),
        };
        let root = a.mk(16);
        a.ck(root)
    });
}
