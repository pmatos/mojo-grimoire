struct S(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def __deinit__(deinit self):
        var a: Array[Int, 2] = [1, 2]
        print(a[3])


def main():
    print(1)
