struct W(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(ref self, i: Int) -> ref [self] W:
        return self

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v

    def __deinit__(deinit self):
        print("del", self.n)


def show(x: W):
    print("show", x.n)


def main():
    var w = W(1)
    show(w[0])
    print("mid")
    print(w.n)
