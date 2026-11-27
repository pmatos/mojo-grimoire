@fieldwise_init
struct Res(Movable):
    var id: Int


def bump(mut r: Res):
    r.id += 10


def main():
    var a = Res(1)
    bump(a^)
    print("bumped")
