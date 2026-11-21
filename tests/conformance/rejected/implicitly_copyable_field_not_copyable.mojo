@fieldwise_init
struct Res(Movable):
    var id: Int

@fieldwise_init
struct S(ImplicitlyCopyable):
    var r: Res


def main():
    print(1)
