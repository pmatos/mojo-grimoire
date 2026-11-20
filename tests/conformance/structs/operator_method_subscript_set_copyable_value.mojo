@fieldwise_init
struct A(Copyable):
    var n: Int


struct W(Copyable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^

    def __getitem__(self, i: Int) -> A:
        return self.a.copy()

    def __setitem__(mut self, i: Int, v: A):
        print("set", v.n)
        self.a = v.copy()


def main():
    var w = W(A(1))
    var u = A(7)
    w[0] = u
    print(w.a.n, u.n)
