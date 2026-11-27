@fieldwise_init
struct Res(Movable):
    var id: Int


def bump(mut r: Res):
    r.id += 10


def main():
    bump(Res(1))
    print("bumped")
