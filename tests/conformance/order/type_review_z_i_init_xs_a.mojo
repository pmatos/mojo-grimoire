struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct A(ImplicitlyCopyable):
    var xs: List[Int]
    var a: A

    def __init__(out self):
        pass

    def m(self):
        var b: Bool = 5
        print(b)


def main():
    print(1)
