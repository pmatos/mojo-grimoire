struct Token(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


def peek(t: Token) -> Int:
    return 0


def build(mut ts: List[Token]) -> Token:
    return Token(2)


def main():
    var ts: List[Token] = [Token(1)]
    var t = Token(1)
    var u = t^
    ts[peek(t)] = build(ts)
    print(u.id)
