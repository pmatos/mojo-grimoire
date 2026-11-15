@fieldwise_init
struct Pair(ImplicitlyCopyable, Movable):
    var a: Int
    var b: Int


def main():
    var p = Pair(1, 2)
    var q = p
    q.a = 10
    print(p.a, q.a)
