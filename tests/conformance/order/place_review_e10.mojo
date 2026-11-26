@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct P(Movable):
    var x: Int

@fieldwise_init
struct H(Movable):
    var l: List[Int]
    var s: S


struct G(Movable):
    var v: List[Int]
    def __init__(out self):
        self.v = [1]
    def __getitem__(self, i: Int) -> Int:
        return self.v[i]

struct GS(Movable):
    var v: List[Int]
    def __init__(out self):
        self.v = [1]
    def __getitem__(self, i: Int) -> Int:
        return self.v[i]
    def __setitem__(mut self, i: Int, x: Int):
        self.v[i] = x

struct SO(Movable):
    var v: List[Int]
    def __init__(out self):
        self.v = [1]
    def __setitem__(mut self, i: Int, x: Int):
        self.v[i] = x

@fieldwise_init
struct W(Movable):
    var g: GS
    var l: List[Int]

struct GR(Movable):
    var v: List[S]
    def __init__(out self):
        self.v = [S(0)]
    def __getitem__(self, i: Int) -> S:
        return S(self.v[i].k)

struct GRS(Movable):
    var v: List[Int]
    def __init__(out self):
        self.v = [1]
    def __getitem__(self, i: Int) -> Int:
        return self.v[i]
    def __setitem__(mut self, i: Int, x: Int):
        self.v[i] = x

def main():
    var g = GR()
    g[zz].k = 1
