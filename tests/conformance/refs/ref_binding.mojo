@fieldwise_init
struct Box(Movable):
    var v: Int


def main():
    var b = Box(1)
    ref r = b
    r.v = 5
    print(b.v)
