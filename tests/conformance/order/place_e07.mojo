@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct P(Movable):
    var x: Int

def main():
    var l: List[S] = [S(0)]
    print(l[zz].nope)
