struct W(Copyable, Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(ref self, i: Int) -> ref [self] W:
        return self

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v

@fieldwise_init
struct P(Copyable, Movable):
    var x: Int

def h(mut x: Int):
    pass

def main():
    var w = W(1)
    print(w[zz].n)
