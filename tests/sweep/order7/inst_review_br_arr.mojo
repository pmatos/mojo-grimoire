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
def main():
    var x = S(1, False)
    var y = S(2, True)
    var xs: List[Int] = [1, 2, 3]
    var a: Array[Int, 2] = [1, 2]
    var k = 1
    var z = (y or S(a[5], True)) + y
