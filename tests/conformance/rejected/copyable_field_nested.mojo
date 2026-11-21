@fieldwise_init
struct Res(Movable):
    var id: Int


@fieldwise_init
struct Outer(Copyable):
    var i: Inner


@fieldwise_init
struct Inner(Copyable):
    var r: Res


def main():
    print(1)
