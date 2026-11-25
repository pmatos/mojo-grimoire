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
    var xs: Array[Int, 2] = [1, 2]
    xs[peek(t)] = spend(t^)
    print(xs[0], xs[1])
