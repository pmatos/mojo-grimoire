@fieldwise_init
struct T(Copyable, Movable):
    var a: Int

def main():
    var xs: List[Int] = [1, 2]
    xs[-1] = [1, 2]
    print(xs[0])
