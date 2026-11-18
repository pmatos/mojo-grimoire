@fieldwise_init
struct Tag(Movable):
    var n: Int


def eat(var t: Tag) -> Int:
    return 5


def pair(a: Int, b: Int) -> Int:
    return a * 100 + b


def main():
    var t = Tag(3)
    print(pair([t.n], eat(t^)))
