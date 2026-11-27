@fieldwise_init
struct Res(Movable):
    var id: Int


def make() -> Res:
    return Res(3)


def bump(mut r: Res):
    r.id += 10


def main():
    bump(make())
    print("bumped")
