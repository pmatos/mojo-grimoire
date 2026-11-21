@fieldwise_init
struct Res(Movable):
    var id: Int

@fieldwise_init
struct S(Copyable):
    var r: List[Res]


def main():
    print(1)
