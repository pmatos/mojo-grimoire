struct S(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def __deinit__(deinit self):
        print(1)


def f():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def main():
    var c = True
    if c:
        var s = S(1)
        print(s.x)
        var a: Array[Int, 2] = [1, 2]
        var b = a[5]
        print(b)
