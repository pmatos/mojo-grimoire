@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        print("get", self.n, i)
        return self.n + i

    def __deinit__(deinit self):
        print("del W", self.n)


def pr(k: Int) -> Int:
    print("pr", k)
    return k


def bump(mut w: W) -> Int:
    w.n += 10
    return 0


def main():
    var w = W(1)
    print(w[0], bump(w))
    var k = w[2] + pr(3)
    print(k)
    print(w[0] + w[1], 5)
    print("end")
