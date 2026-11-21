@fieldwise_init
struct P(Copyable):
    var id: Int


@fieldwise_init
struct S(Copyable):
    var p: P
    var xs: List[P]
    var a: Array[P, 2]


def main():
    var s = S(P(1), [P(2)], [P(3), P(4)])
    var t = s.copy()
    t.xs[0].id = 9
    print(s.xs[0].id, t.xs[0].id, t.p.id)
