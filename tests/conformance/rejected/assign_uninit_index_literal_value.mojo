@fieldwise_init
struct T(Copyable, Movable):
    var a: Int

def main():
    var j: Int
    var xs: List[Int] = [1, 2]
    xs[j] = [1, 2]
    print(xs[0])
