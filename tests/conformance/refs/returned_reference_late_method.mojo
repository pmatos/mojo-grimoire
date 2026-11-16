@fieldwise_init
struct C(Movable):
    var v: Int

    def choose(self, ref a: Int, ref b: Int) -> ref[a, b] Int:
        if self.v > 0:
            return a
        return b


def bump(mut x: Int) -> Int:
    x += 10
    return 0


def id(ref x: Int) -> ref[x] Int:
    return x


def two(x: Int, y: Int) -> Int:
    return x * 100 + y


def main():
    var c = C(1)
    var a = 1
    var b = 2
    print(c.choose(a, b), bump(a))
    print(c.choose(a, b) + bump(a))
    print(two(c.choose(a, b), bump(a)))
    print(id(5) + 1, id(a))
    var l: List[Int] = [c.choose(a, b), bump(a)]
    print(l)
    print(id(id(a)), bump(a))
