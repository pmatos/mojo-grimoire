struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def __deinit__(deinit self):
        print("drop", self.id)


struct Two(Movable):
    var a: Res
    var b: Res

    def __init__(out self, var a: Res, var b: Res):
        self.a = a^
        self.b = b^


def f(mut q: Two):
    var j = q.a^
    var t = Two(Res(1), Res(2))
    var y = t.a^
    t = Two(Res(3), Res(4))
    print(y.id, j.id)


def main():
    var q = Two(Res(1), Res(2))
    f(q)
