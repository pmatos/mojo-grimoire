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
    var o = O(True)
    var p = O(False)
    var x = o.f or p.f
    print(x)
    var q = O(True)
    var r = O(False)
    var y = q.f and pb(r.f)
    print(y)
    print("end")
