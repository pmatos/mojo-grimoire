@fieldwise_init
struct Pair(Movable):
    var a: Int
    var b: Bool


struct Counter(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def plus(self, k: Int) -> Int:
        return self.n + k


def seven() -> Int:
    return [7]


def by_read(x: Int) -> Int:
    return x


def by_var(var x: Int) -> Int:
    return x


def by_ref(ref x: Int) -> Int:
    return x


def loud(n: Int) -> Int:
    print("loud", n)
    return n


def main():
    var x: Int = [1]
    var y: Int = [[[2]]]
    print(x, y)
    x = [x + 10]
    print(x, seven())
    var z: Int = [loud(3)]
    print(z)
    var w: Int = [z^]
    print(w, z)
    print(by_read([4]), by_var([5]), by_ref([6]))
    var p = Pair([8], True)
    p.a = [9]
    var c = Counter([3])
    print(p.a, c.plus([4]))
    var xs: List[Int] = [5, 6]
    xs.append([7])
    xs[0] = [8]
    print(xs.pop([0]))
    print(xs)
