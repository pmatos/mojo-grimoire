struct O(Movable):
    var f: Bool

    def __init__(out self, f: Bool):
        self.f = f

    def __deinit__(deinit self):
        print("del O", self.f)


def pb(b: Bool) -> Bool:
    print("pb", b)
    return b


def wrap(b: Bool) -> Bool:
    print("wrap", b)
    return b


def rd(o: O) -> Bool:
    print("rd", o.f)
    return o.f


def main():
    var o = O(False)
    var p = O(True)
    o = O(wrap(o.f == pb(p.f)))
    print(o.f)
    o = O(wrap(rd(o)))
    print(o.f)
    o = O(wrap(pb(o.f)))
    print(o.f)
    print("end")
