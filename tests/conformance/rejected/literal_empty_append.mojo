@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var ss: List[S] = []
    ss.append([])
