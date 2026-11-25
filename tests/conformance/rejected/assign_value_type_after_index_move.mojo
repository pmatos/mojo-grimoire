struct Token(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


def spend(var t: Token) -> Int:
    return 0


def peek(t: Token) -> Int:
    return t.id

def flag(b: Bool) -> Int:
    return 0


def main():
    var t = Token(1)
    var xs: List[Int] = [1, 2]
    xs[spend(t^) + peek(t)] = flag(2)
    print(xs[0])
