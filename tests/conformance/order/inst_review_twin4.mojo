struct S(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def __deinit__(deinit self):
        pass


def main():
    var a: Array[Int, 2] = [1, 2]
    var s = S(1)
    print(s.x)
    var y: Int = [1, 2, 3]
    print(y)
    print(a[5])
