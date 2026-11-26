@fieldwise_init
struct S(Copyable):
    var x: Int

    def __bool__(self) -> Bool:
        var a: Array[Int, 2] = [1, 2]
        print(a[3])
        return True


def f():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def main():
    f()
    var s = S(1)
    if s:
        print(1)
