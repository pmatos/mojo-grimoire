struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del T", self.n)


struct O(Movable):
    var f: Bool

    def __init__(out self, f: Bool):
        self.f = f

    def __deinit__(deinit self):
        print("del O", self.f)


def pb(b: Bool) -> Bool:
    print("pb", b)
    return b


def main():
    var a = T(0)
    var b = T(5)
    a = a or b
    print(a.n)
    var c = T(3)
    var d = T(7)
    c = c and d
    print(c.n)
    var o = O(False)
    var p = O(True)
    o = O(o.f or pb(p.f))
    print(o.f)
    var q = O(True)
    var s = O(True)
    q = O(q.f and pb(s.f))
    print(q.f)
    print("end")
