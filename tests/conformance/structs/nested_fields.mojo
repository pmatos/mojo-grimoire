@fieldwise_init
struct Inner(Copyable, Movable):
    var v: Int


@fieldwise_init
struct Outer(Copyable, Movable):
    var inner: Inner
    var w: Int


def main():
    var o = Outer(Inner(1), 2)
    o.inner.v += 40
    print(o.inner.v, o.w)
