@fieldwise_init
struct S(Copyable, Movable):
    var k: Int

@fieldwise_init
struct G(Copyable, Movable):
    var k: Int

    def __getitem__(self, i: Int) -> S:
        return S(self.k)

def main():
    var s = G(1)
    print(s[zz].k)
