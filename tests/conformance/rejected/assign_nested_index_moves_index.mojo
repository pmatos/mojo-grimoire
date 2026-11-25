struct Token(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


def spend(var t: Token) -> Int:
    return 0


def peek(t: Token) -> Int:
    return t.id

def main():
    var t = Token(1)
    var xs: List[List[Int]] = [[1, 2], [3]]
    xs[spend(t^)][peek(t)] = 5
    print(xs[0][1])
