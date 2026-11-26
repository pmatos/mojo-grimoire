struct D1(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def __deinit__(deinit self):
        var a: Array[Int, 2] = [1, 2]
        print(a[3])


struct D2(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def __deinit__(deinit self):
        var a: Array[Int, 2] = [1, 2]
        print(a[4])


struct W(Movable):
    var a: D1
    var b: D2

    def __init__(out self):
        self.a = D1(1)
        self.b = D2(2)


def main():
    var w = W()
    print(w.a.x)
