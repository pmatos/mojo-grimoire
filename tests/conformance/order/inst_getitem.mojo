@fieldwise_init
struct S(Copyable):
    var x: Int

    def __getitem__(self, i: Int) -> Int:
        var a: Array[Int, 2] = [1, 2]
        print(a[3])
        return self.x


def f():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def main():
    f()
    var s = S(1)
    print(s[0])
