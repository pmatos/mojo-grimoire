@fieldwise_init
struct K(Copyable):
    var i: Int


def take(var k: K) -> Int:
    return k.i


@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        return self.n + i


def main():
    var w = W(1)
    var k = K(2)
    w[take(k)] = 5
