@fieldwise_init
struct S(Movable):
    var k: Int


struct W(Movable):
    var k: Int

    def __init__(out self, mut x: S):
        self.k = x.k


def main():
    var l: List[S] = [S(1)]
    var m = l^
    var w = W(l[0]^)
    print(w.k, len(m))
