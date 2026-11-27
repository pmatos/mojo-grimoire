@fieldwise_init
struct V(ImplicitlyCopyable):
    var n: Int


def main():
    var v = V(1)
    print(v and V(zz))
