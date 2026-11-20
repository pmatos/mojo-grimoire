@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        print("get", self.n, i)
        return self.n + i

    def __setitem__(mut self, i: Int, v: Int):
        print("set", i, v)
        self.n = v

    def __deinit__(deinit self):
        print("del W", self.n)


def pr(k: Int) -> Int:
    print("pr", k)
    return k


def main():
    var w = W(1)
    print(w[2])
    w[pr(2)] = pr(3)
    print(w.n)
    var v = W(5)
    print(v[w[1]])
    print("end")
