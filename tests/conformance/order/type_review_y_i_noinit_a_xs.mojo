struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct A(ImplicitlyCopyable):
    var a: A
    var xs: List[Int]


def main():
    print(1)
