@fieldwise_init
struct P(ImplicitlyCopyable):
    var v: Int

    def __deinit__(deinit self):
        print("drop", self.v)


def pick(ref a: P, ref b: P, first: Bool) -> ref[a, b] P:
    if first:
        return a
    return b


def bump(mut p: P) -> Int:
    p.v += 10
    return 0


def own(var x: P, y: Int) -> Int:
    print(x.v, y)
    return 0


def own3(var x: P, var y: P, z: Int) -> Int:
    print(x.v, y.v, z)
    return 0


def own4(var x: P, var y: P, var z: P) -> Int:
    print(x.v, y.v, z.v)
    return 0


def simple():
    var a = P(1)
    var b = P(2)
    print(own(pick(a, b, True), bump(a)))


def listed():
    var a = P(1)
    var b = P(2)
    var l: List[P] = [pick(a, b, False), P(bump(a))]
    print(len(l))


def after_place():
    var c = P(3)
    var a = P(1)
    var b = P(2)
    print(own3(c, pick(a, b, True), bump(a)))


def before_place():
    var a = P(1)
    var b = P(2)
    var c = P(3)
    print(own3(pick(b, a, True), c, bump(a)))


def two_calls():
    var a = P(1)
    var b = P(2)
    var c = P(3)
    var d = P(4)
    print(own4(pick(a, b, False), pick(c, d, True), P(bump(a))))


def main():
    simple()
    print("--")
    listed()
    print("--")
    after_place()
    print("--")
    before_place()
    print("--")
    two_calls()
    print("end")
