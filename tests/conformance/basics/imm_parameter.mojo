@fieldwise_init
struct Pair(Movable):
    var a: Int
    var b: Int

    def sum(imm self) -> Int:
        return self.a + self.b


def total(imm xs: List[Int]) -> Int:
    return xs[0] + xs[1]


def first(imm xs: Array[Int, 2]) -> Int:
    return xs[0]


def main():
    var p = Pair(1, 2)
    var xs: List[Int] = [3, 4]
    var ys: Array[Int, 2] = [5, 6]
    var imm = 8
    var read = 9
    var owned = 10
    print(p.sum(), total(xs), len(xs), first(ys), imm, read, owned)
