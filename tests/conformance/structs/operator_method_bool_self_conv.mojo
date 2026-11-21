struct V(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(var self) -> Bool:
        print("bool V", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del V", self.n)


struct M(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(mut self) -> Bool:
        self.n += 10
        return self.n != 10

    def __deinit__(deinit self):
        print("del M", self.n)


def main():
    var a = V(0)
    var b = V(2)
    var c = a or b
    print(c.n, a.n, b.n)
    var d = V(0) or V(3)
    print(d.n)
    var e = V(4) and V(5)
    print(e.n)
    var m = M(0)
    var k = M(1)
    var r = m or k
    print(r.n, m.n, k.n)
    print("end")
