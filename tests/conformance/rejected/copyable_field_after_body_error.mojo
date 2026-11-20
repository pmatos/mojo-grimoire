@fieldwise_init
struct Res(Movable):
    var id: Int

@fieldwise_init
struct S(Copyable):
    var r: Res


def main():
    print(y)
