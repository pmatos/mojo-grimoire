@fieldwise_init
struct U(Copyable):
    var n: Int


@fieldwise_init
struct V(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> U:
        return U(self.n + i)


def rd(u: U) -> Int:
    return u.n


def main():
    var v = V(1)
    var u = v[2]
    print(u.n, rd(v[3]))
