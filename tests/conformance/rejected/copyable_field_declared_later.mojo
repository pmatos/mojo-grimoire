@fieldwise_init
struct Outer(Copyable):
    var i: Inner

@fieldwise_init
struct Inner(Movable):
    var x: Int


def main():
    print(1)
