@fieldwise_init
struct T(ImplicitlyCopyable):
    var k: Int


def g(mut x: T):
    x.k += 1


def main():
    var l: List[T] = [T(1)]
    g(l[0]^)
    print(l[0].k)
