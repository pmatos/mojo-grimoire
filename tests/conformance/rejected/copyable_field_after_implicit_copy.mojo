@fieldwise_init
struct Res(Movable):
    var id: Int

@fieldwise_init
struct S(Copyable):
    var r: Res


def main():
    var s = S(Res(1))
    var t = s
    print(t.r.id)
