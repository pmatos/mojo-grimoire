@fieldwise_init
struct S(Copyable):
    var x: Int

    def m(self):
        f()


def f():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])


def g():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def main():
    g()
    var s = S(1)
    s.m()
