@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


def main():
    var p = Pair(1, 2)
    var q = p^
    p.x = 3
    print(q.x, p.x)
