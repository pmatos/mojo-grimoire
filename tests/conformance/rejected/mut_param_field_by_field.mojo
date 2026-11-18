@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


def swap(mut p: Pair):
    var old = p^
    p.x = old.y
    p.y = old.x


def main():
    var p = Pair(1, 2)
    swap(p)
    print(p.x)
