@fieldwise_init
struct Res(Movable):
    var id: Int

@fieldwise_init
struct Inner(Copyable):
    var r: Res

@fieldwise_init
struct Outer(Copyable):
    var i: Inner


def main():
    print(1)
