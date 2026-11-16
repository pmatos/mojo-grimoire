@fieldwise_init
struct Pair(Movable):
    var items: Array[Int, 2]


def first(ref p: Pair) -> ref [p] Int:
    return p.items[0]


def main():
    var p = Pair([1, 2])
    print(first(p))
