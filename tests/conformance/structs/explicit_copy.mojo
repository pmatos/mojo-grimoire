@fieldwise_init
struct Box(Copyable, Movable):
    var v: Int


def main():
    var a = Box(1)
    var b = a.copy()
    b.v = 2
    print(a.v, b.v)
