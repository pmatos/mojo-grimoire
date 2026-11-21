@fieldwise_init
struct R(TrivialRegisterPassable):
    var x: Int


def main():
    var a = R(1)
    var b = a
    b.x = 2
    print(a.x, b.x)
