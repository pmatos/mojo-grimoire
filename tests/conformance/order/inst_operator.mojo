@fieldwise_init
struct S(Copyable):
    var x: Int

    def __add__(self, o: Self) -> Self:
        var a: Array[Int, 2] = [1, 2]
        print(a[3])
        return S(self.x + o.x)


def f():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def main():
    f()
    var s = S(1)
    var t = s + S(2)
    print(t.x)
