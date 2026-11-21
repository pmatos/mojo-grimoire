@fieldwise_init
struct R(TrivialRegisterPassable):
    var x: Int


def take(var r: R):
    r.x = 5
    print(r.x)


def main():
    var a = R(1)
    take(a)
    print(a.x)
