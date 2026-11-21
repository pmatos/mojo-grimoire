@fieldwise_init
struct R(TrivialRegisterPassable):
    var x: Int


@fieldwise_init
struct S(ImplicitlyCopyable):
    var r: R


def main():
    var s = S(R(1))
    var t = s
    t.r.x = 2
    print(s.r.x, t.r.x)
