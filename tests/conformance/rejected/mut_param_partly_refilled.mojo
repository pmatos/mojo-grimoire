@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


def half(mut p: Pair):
    var old = p^
    p.x = old.y


def main():
    var p = Pair(1, 2)
    half(p)
    print(p.x)
