@fieldwise_init
struct Res(Movable):
    var id: Int


def main():
    var xs = [Res(1), Res(2)]
    var r = xs[0]^
    print(r.id)
