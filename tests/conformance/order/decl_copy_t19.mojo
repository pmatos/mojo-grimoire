@fieldwise_init
struct S(Movable):
    var k: Int

def g(s: S) -> Int:
    return s

def main():
    print(g(S(1)))
