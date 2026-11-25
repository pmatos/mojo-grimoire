@fieldwise_init
struct T(Copyable, Movable):
    var a: Int

def main():
    var j: Int
    var xs: List[Int] = [1, 2]
    xs[-1] = j
    print(xs[0])
