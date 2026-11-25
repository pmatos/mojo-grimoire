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


def main():
    var l1: List[D1] = [D1(1)]
    var l2: List[D2] = [D2(2)]
    print(len(l1), len(l2))
