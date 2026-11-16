@fieldwise_init
struct Token(Movable):
    var id: Int


def main():
    var t = Token(1)
    print(t)
