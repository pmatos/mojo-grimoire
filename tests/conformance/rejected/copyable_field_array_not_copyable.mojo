@fieldwise_init
struct Res(Movable):
    var id: Int

@fieldwise_init
struct S(Copyable):
    var r: Array[Res, 2]


def main():
    print(1)
