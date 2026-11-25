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
    var n = 0
    while n < 1:
        var t = Two(Res(1), Res(2))
        var y = t.a^
        print(y.id)
        n += 1
    print(j.id)


def main():
    var q = Two(Res(1), Res(2))
    f(q)
