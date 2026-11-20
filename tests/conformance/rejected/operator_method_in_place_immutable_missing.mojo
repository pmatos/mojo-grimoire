@fieldwise_init
struct T(Copyable):
    var n: Int


def g(t: T):
    t += 1


def main():
    g(T(1))
