@fieldwise_init
struct Token(Movable):
    var tag: Int

    def __deinit__(deinit self):
        print("gone", self.tag)


def main():
    var ts = List[Token]()
    ts.append(Token(10))
    ts.append(Token(20))
    ts.append(Token(30))
    var top = ts.pop()
    print("took", top.tag)
    ts.pop()
    print("left", len(ts))
    var us = List[Token]()
    us.append(Token(40))
    us.append(Token(50))
    var kept = us.pop()
    print("kept", kept.tag)
    print("done", top.tag)
