struct S(ImplicitlyCopyable):
    var n: Int
    var f: Bool
    def __init__(out self, n: Int, f: Bool):
        self.n = n
        self.f = f
    def __bool__(self) -> Bool:
        return self.f
    def __add__(self, o: S) -> S:
        return S(self.n + o.n, self.f)
    def __neg__(self) -> S:
        return self
    def __lt__(self, o: S) -> Bool:
        return self.n < o.n
struct U(ImplicitlyCopyable):
    var f: Bool
    def __init__(out self, f: Bool):
        self.f = f
    def __bool__(self) -> Int:
        return 1
struct V(ImplicitlyCopyable):
    var f: Bool
    def __init__(out self, f: Bool):
        self.f = f
    def __bool__(mut self) -> Bool:
        return self.f
struct M(Movable):
    var f: Bool
    def __init__(out self, f: Bool):
        self.f = f
    def __bool__(self) -> Bool:
        return self.f
@fieldwise_init
struct H(Movable):
    var y: List[Int]
    var x: Int
def bi(a: Int) -> Int:
    return a
def fb(a: Int, b: Bool) -> Int:
    return a
struct R(ImplicitlyCopyable):
    var n: Int
    def __init__(out self, n: Int):
        self.n = n
    def __bool__(self) -> Bool:
        return self.n > 0
    def __radd__(self, o: Int) -> Int:
        return o + self.n
    def __sub__(mut self, o: R) -> R:
        return self
def gi() -> Int:
    return 1
def main():
    var x = S(1, False)
    var y = S(2, True)
    var xs: List[Int] = [1, 2, 3]
    var k = 1
    var u = U(True)
    var u2 = U(False)
    var v = V(True)
    var ls: List[S] = [S(1, True)]
    var m = M(True)
    var m2 = M(False)
    var cx = 1
    var cy: List[Int] = [1]
    var rl: List[List[Int]] = [[1]]
    var al: Array[List[Int], 1] = [[1]]
    var h = H([1], 1)
    var a = [1, 2]
    var n = [[1], [2]]
    var cxs = [1, 2]
    var r = R(1)
    var r2 = R(2)
    var ys: List[Int]
    print(not m, [h.y] <= al)
