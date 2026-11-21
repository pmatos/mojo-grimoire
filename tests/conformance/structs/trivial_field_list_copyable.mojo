@fieldwise_init
struct R(TrivialRegisterPassable, Movable):
    var x: Int


@fieldwise_init
struct S(Copyable):
    var rs: List[R]


def main():
    var s = S([R(1), R(2)])
    var t = s.copy()
    t.rs[0].x = 9
    print(s.rs[0].x, t.rs[0].x, len(t.rs))
