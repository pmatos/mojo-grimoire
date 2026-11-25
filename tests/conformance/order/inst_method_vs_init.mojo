struct S(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x
        var a: Array[Int, 2] = [1, 2]
        print(a[3])

    def m(self):
        var a: Array[Int, 2] = [1, 2]
        print(a[4])


def main():
    var s = S(1)
    s.m()
    var t = S(2)
    print(t.x)
