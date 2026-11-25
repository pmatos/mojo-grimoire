struct D(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def __deinit__(deinit self):
        var a: Array[Int, 2] = [1, 2]
        print(a[3])


struct W(Movable):
    var d: D

    def __init__(out self, var d: D):
        self.d = d^


def f():
    var y: Int = [1, 2]
    print(y)


def main():
    var ls: List[D] = [D(1)]
    f()
    print(len(ls))
