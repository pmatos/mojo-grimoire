@fieldwise_init
struct S(Copyable, Movable):
    var k: Int

@fieldwise_init
struct G(Copyable, Movable):
    var k: Int

    def __getitem__(self, i: Int) -> S:
        return S(self.k)

def f(s: G):
    s[0].k = 1

def main():
    f(G(1))
