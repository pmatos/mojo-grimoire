struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct A(ImplicitlyCopyable):
    var a: A
    var xs: List[Int]

    def m(self):
        var b: Bool = 5
        print(b)


def main():
    print(1)
