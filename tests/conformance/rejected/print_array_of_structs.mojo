@fieldwise_init
struct Token(Movable):
    var id: Int


def main():
    var ts = [Token(1), Token(2)]
    print(ts)
