@fieldwise_init
struct S(Movable):
    var k: Int


struct W(Movable):
    var k: Int

    def __init__(out self, mut x: S):
        self.k = x.k


def main():
    var s = S(7)
    ref t = s
    var w = W(t^)
    print(w.k)
