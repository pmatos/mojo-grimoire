@fieldwise_init
struct S(Movable):
    var k: Int

def main():
    var t: List[S] = [[]]
    print(len(t))
