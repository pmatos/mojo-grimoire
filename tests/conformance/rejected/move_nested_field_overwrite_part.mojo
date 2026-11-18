@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Cell(Movable):
    var p: Pair


@fieldwise_init
struct Row(Movable):
    var c: Cell
    var n: Int


def main():
    var r = Row(Cell(Pair(1, 2)), 3)
    var k = r.c.p^
    r.c = Cell(Pair(5, 6))
    print(k.x, r.c.p.x, r.n)
