@fieldwise_init
struct P(Movable):
    var x: Int

struct G(Movable):
    var v: Int
    def __init__(out self):
        self.v = 0
    def __getitem__(self, i: Int) -> Int:
        return self.v

struct GS(Movable):
    var v: Int
    def __init__(out self):
        self.v = 0
    def __getitem__(self, i: Int) -> Int:
        return self.v
    def __setitem__(mut self, i: Int, v: Int):
        self.v = v

@fieldwise_init
struct H(Movable):
    var g: G

struct GL(Movable):
    var v: Int
    def __init__(out self):
        self.v = 0
    def __getitem__(self, i: Int) -> List[Int]:
        return [self.v]

struct GP(Movable):
    var v: Int
    def __init__(out self):
        self.v = 0
    def __getitem__(self, i: Int) -> P:
        return P(self.v)

def f(g: GP):
    g[0].x = 1

def main():
    f(GP())
