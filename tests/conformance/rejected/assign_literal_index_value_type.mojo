@fieldwise_init
struct T(Copyable, Movable):
    var a: Int

def main():
    var xs: List[Int] = [1, 2]
    xs[[1, 2]] = T(1)
    print(xs[0])
