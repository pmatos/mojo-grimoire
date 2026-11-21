@fieldwise_init
struct K(Copyable):
    var i: Int


@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, k: K) -> Int:
        return self.n + k.i


def main():
    var w = W(1)
    var k = K(2)
    print(w[k])
    w[k] = 5
