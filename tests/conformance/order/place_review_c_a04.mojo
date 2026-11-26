@fieldwise_init
struct S(Copyable, Movable):
    var k: Int

@fieldwise_init
struct P(Copyable, Movable):
    var x: Int

@fieldwise_init
struct G(Copyable, Movable):
    var k: Int

    def __getitem__(self, i: Int) -> S:
        return S(self.k)

@fieldwise_init
struct H(Copyable, Movable):
    var s: S

    def __getitem__(ref self, i: Int) -> ref [self] S:
        return self.s

def g(x: Int):
    pass

def h(mut x: Int):
    pass

def f(p: P):
    p.nope = zz

def main():
    f(P(1))
